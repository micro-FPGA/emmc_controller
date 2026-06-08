/*
 * SD Card initialization using Lattice eMMC Controller IP
 * Based on LatticeSemi/emmc_controller driver
 *
 * Replaces eMMC init sequence with SD/SDHC-compatible sequence:
 *   CMD0 -> CMD8 -> ACMD41 (CMD55+CMD41) -> CMD2 -> CMD3 -> CMD7
 *
 * Supports: SD v2.0+, SDHC, SDXC
 */

#include "emmc_controller.h"
#include <stdint.h>

/* ------------------------------------------------------------------ */
/* SD-specific command codes (not defined in emmc_controller.h)       */
/* ------------------------------------------------------------------ */
#define SD_CMD8_SEND_IF_COND        8   /* voltage range check, SD v2 */
#define SD_CMD55_APP_CMD            55  /* next command is an ACMD    */
#define SD_ACMD41_SD_SEND_OP_COND   41  /* SD equivalent of CMD1      */

/* CMD8 argument: VHS=1 (2.7–3.6V), check pattern 0xAA */
#define SD_CMD8_ARG                 0x000001AA

/* ACMD41 argument: HCS=1 (support SDHC/SDXC), 3.2–3.3V window */
#define SD_ACMD41_ARG               0x40300000

/* OCR bit 31: low = card ready, high = still powering up */
#define SD_OCR_NOT_BUSY             (1u << 31)

/* OCR CCS bit 30: 1 = SDHC/SDXC (block addressing), 0 = standard */
#define SD_OCR_CCS                  (1u << 30)

/* How many ACMD41 retries before giving up */
#define SD_ACMD41_RETRY_MAX         1000

/* Clear all interrupt/status bits at once */
#ifndef SET_ALL_BITS
#define SET_ALL_BITS                0xFFFFFFFF
#endif

/* ------------------------------------------------------------------ */
/* Internal helper: send one command, poll until done                 */
/* Mirrors exactly the pattern used in emmc_controller.c              */
/* ------------------------------------------------------------------ */
static unsigned char sd_send_cmd(emmc_ctl_handle_t *handle,
                                 unsigned int       cmd_code,
                                 unsigned int       argument)
{
    emmc_ctl_reg_t *reg = (emmc_ctl_reg_t *)(handle->base_addr);
    unsigned int    rdat;
    unsigned char   det_err;

    reg->EMMC_REG_INT_STATUS = SET_ALL_BITS;   /* clear previous status */
    reg->EMMC_REG_CONFIG1    = 0;
    reg->EMMC_REG_CTRL0      = 0;
    reg->EMMC_REG_CTRL1      = argument;       /* command argument      */
    reg->EMMC_REG_CTRL2      = (EMMC_CTRL2_START | cmd_code);

    wait_emmc_ctl_busy_status(handle, 0);

    rdat    = reg->EMMC_REG_INT_STATUS;
    det_err = ((rdat & 0xFFFFFFFE) == 0) ? 0 : 1;

    reg->EMMC_REG_INT_STATUS = SET_ALL_BITS;   /* clear status          */

    return (det_err == 0) ? SUCCESS : FAILURE;
}

/* ------------------------------------------------------------------ */
/* SD card initialization                                             */
/*                                                                    */
/* Call this instead of the eMMC card init sequence.                  */
/* On success returns SUCCESS and optionally sets *is_high_capacity:  */
/*   1 = SDHC/SDXC  (use block addressing in read/write commands)     */
/*   0 = Standard SD (use byte addressing)                            */
/* ------------------------------------------------------------------ */
unsigned char sd_card_init(emmc_ctl_handle_t *handle,
                           unsigned char     *is_high_capacity)
{
    emmc_ctl_reg_t *reg = (emmc_ctl_reg_t *)(handle->base_addr);
    unsigned int    resp;
    unsigned int    rca = 0;
    int             retry;
    unsigned char   ret;

    if (is_high_capacity) *is_high_capacity = 0;

    /* ----------------------------------------------------------------
     * Step 1: CMD0 — GO_IDLE_STATE
     * Reset card to idle. No response expected.
     * Reuse existing driver function directly.
     * ---------------------------------------------------------------- */
    emmc_cmd_go_idle(handle);

    /* ----------------------------------------------------------------
     * Step 2: CMD8 — SEND_IF_COND
     * SD v2 voltage compatibility check.
     * If the card does not respond this is an SD v1 card — that is
     * OK, we continue but ACMD41 will not set the HCS bit.
     * Expected response: card echoes back the argument (0x1AA).
     * ---------------------------------------------------------------- */
    ret = sd_send_cmd(handle, SD_CMD8_SEND_IF_COND, SD_CMD8_ARG);
    if (ret == SUCCESS) {
        /* SD v2 card — verify check pattern in response */
        emmc_get_resp_data(handle);
        resp = reg->EMMC_REG_RESP_D1;
        if ((resp & 0x000001FF) != (SD_CMD8_ARG & 0x000001FF)) {
            return FAILURE;   /* voltage/pattern mismatch, unusable card */
        }
    }
    /* CMD8 failure = SD v1, just continue */

    /* ----------------------------------------------------------------
     * Step 3: ACMD41 — SD_SEND_OP_COND  (poll until card ready)
     * SD app commands require CMD55 prefix before each one.
     * Repeat until OCR bit 31 goes high (card finished powering up).
     * ---------------------------------------------------------------- */
    for (retry = 0; retry < SD_ACMD41_RETRY_MAX; retry++) {

        /* CMD55: tell card the next command is an application command */
        ret = sd_send_cmd(handle, SD_CMD55_APP_CMD, 0x00000000);
        if (ret != SUCCESS) return FAILURE;

        /* ACMD41: send operating conditions */
        ret = sd_send_cmd(handle, SD_ACMD41_SD_SEND_OP_COND, SD_ACMD41_ARG);
        if (ret != SUCCESS) return FAILURE;

        emmc_get_resp_data(handle);
        resp = reg->EMMC_REG_RESP_D1;   /* OCR register is in RESP_D1 */

        if (resp & SD_OCR_NOT_BUSY) {
            /* Card is ready */
            if (is_high_capacity)
                *is_high_capacity = (resp & SD_OCR_CCS) ? 1 : 0;
            break;
        }

        /* Card still initialising — short busy-wait then retry */
        for (volatile int d = 0; d < 10000; d++);
    }

    if (retry >= SD_ACMD41_RETRY_MAX)
        return FAILURE;   /* card never became ready */

    /* ----------------------------------------------------------------
     * Step 4: CMD2 — ALL_SEND_CID
     * Request 128-bit Card Identification register.
     * Reuse existing driver function.
     * ---------------------------------------------------------------- */
    ret = emmc_cmd_all_send_cid(handle);
    if (ret != SUCCESS) return FAILURE;

    /* ----------------------------------------------------------------
     * Step 5: CMD3 — SEND_RELATIVE_ADDR
     * Unlike eMMC where the HOST assigns the RCA as the argument,
     * SD cards IGNORE the argument (we send 0x0) and instead the
     * CARD itself chooses and returns its own RCA in the R6 response.
     * We then read that RCA back from RESP_D1 upper 16 bits.
     * ---------------------------------------------------------------- */
    ret = sd_send_cmd(handle, EMMC_CMD_SET_RELATIVE_ADDR, 0x00000000);
    if (ret != SUCCESS) return FAILURE;

    emmc_get_resp_data(handle);
    rca = reg->EMMC_REG_RESP_D1;          /* full R6 response word    */
    rca = (rca >> 16) & 0xFFFF;           /* extract RCA field        */

    handle->tgt_addr = (rca << 16);       /* store in format CMD7 expects */

    /* ----------------------------------------------------------------
     * Step 6: CMD7 — SELECT_CARD
     * Move card from Stand-by to Transfer state.
     * emmc_cmd_select_card() sends handle->tgt_addr as the argument,
     * which now holds the SD card's RCA in the upper 16 bits.
     * ---------------------------------------------------------------- */
    ret = emmc_cmd_select_card(handle);
    if (ret != SUCCESS) return FAILURE;

    /* Card is now in Transfer state — ready for read/write */
    return SUCCESS;
}
