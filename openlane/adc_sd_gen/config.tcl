set ::env(DESIGN_NAME) adc_sd_top

set ::env(VERILOG_FILES) [glob $::env(DESIGN_DIR)/../../verilog/rtl/*.v]

set ::env(CLOCK_PORT) clk
set ::env(CLOCK_PERIOD) 195.3125

set ::env(FP_CORE_UTIL) 40
set ::env(PL_TARGET_DENSITY) 0.5

set ::env(FP_PIN_ORDER_CFG) $::env(DESIGN_DIR)/pin_order.cfg

set ::env(DIE_AREA) "0 0 100 100"

set ::env(RUN_CTS) 1

