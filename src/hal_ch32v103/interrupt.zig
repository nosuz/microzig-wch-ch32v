const microzig = @import("microzig");
const root = @import("root");

pub fn enable_interrupt() void {
    asm volatile ("csrwi mstatus, (1 << 3)" ::: "");
}

pub fn disable_interrupt() void {
    asm volatile ("csrr t0, mstatus" ::: "");
    // asm volatile ("andi t0, t0, 0xFFFFFFF7" ::: "");
    asm volatile ("andi t0, t0, ~(1 << 3)" ::: "");
    asm volatile ("csrw mstatus, t0" ::: "");
}

pub const Interrupts = enum(u7) {
    /// Delived from Rust CH32V103 PAC
    /// https://raw.githubusercontent.com/ch32-rs/ch32-rs-nightlies/main/ch32v1/src/ch32v103/mod.rs
    ///1 - Reset
    RESET = 1,
    ///2 - NMI
    NMI = 2,
    ///3 - EXC
    EXC = 3,
    ///12 - SysTick
    SYS_TICK = 12,
    ///14 - SWI
    SWI = 14,
    ///16 - Window Watchdog interrupt
    WWDG = 16,
    ///17 - PVD through EXTI line detection interrupt
    PVD = 17,
    ///18 - Tamper interrupt
    TAMPER = 18,
    ///19 - RTC global interrupt
    RTC = 19,
    ///20 - Flash global interrupt
    FLASH = 20,
    ///21 - RCC global interrupt
    RCC = 21,
    ///22 - EXTI Line0 interrupt
    EXTI0 = 22,
    ///23 - EXTI Line1 interrupt
    EXTI1 = 23,
    ///24 - EXTI Line2 interrupt
    EXTI2 = 24,
    ///25 - EXTI Line3 interrupt
    EXTI3 = 25,
    ///26 - EXTI Line4 interrupt
    EXTI4 = 26,
    ///27 - DMA1 Channel1 global interrupt
    DMA1_CH1 = 27,
    ///28 - DMA1 Channel2 global interrupt
    DMA1_CH2 = 28,
    ///29 - DMA1 Channel3 global interrupt
    DMA1_CH3 = 29,
    ///30 - DMA1 Channel4 global interrupt
    DMA1_CH4 = 30,
    ///31 - DMA1 Channel5 global interrupt
    DMA1_CH5 = 31,
    ///32 - DMA1 Channel6 global interrupt
    DMA1_CH6 = 32,
    ///33 - DMA1 Channel7 global interrupt
    DMA1_CH7 = 33,
    ///34 - ADC1 global interrupt
    ADC = 34,
    ///39 - EXTI Line\[9:5\]
    ///interrupts
    EXTI9_5 = 39,
    ///40 - TIM1 Break interrupt
    TIM1_BRK = 40,
    ///41 - TIM1 Update interrupt
    TIM1_UP = 41,
    ///42 - TIM1 Trigger and Commutation interrupts
    TIM1_TRG_COM = 42,
    ///43 - TIM1 Capture Compare interrupt
    TIM1_CC = 43,
    ///44 - TIM2 global interrupt
    TIM2 = 44,
    ///45 - TIM3 global interrupt
    TIM3 = 45,
    ///46 - TIM4 global interrupt
    TIM4 = 46,
    ///47 - I2C1 event interrupt
    I2C1_EV = 47,
    ///48 - I2C1 error interrupt
    I2C1_ER = 48,
    ///49 - I2C2 event interrupt
    I2C2_EV = 49,
    ///50 - I2C2 error interrupt
    I2C2_ER = 50,
    ///51 - SPI1 global interrupt
    SPI1 = 51,
    ///52 - SPI2 global interrupt
    SPI2 = 52,
    ///53 - USART1 global interrupt
    USART1 = 53,
    ///54 - USART2 global interrupt
    USART2 = 54,
    ///55 - USART3 global interrupt
    USART3 = 55,
    ///56 - EXTI Line\[15:10\]
    ///interrupts
    EXTI15_10 = 56,
    ///57 - RTC Alarms through EXTI line interrupt
    RTCALARM = 57,
    ///58 - USB Device FS Wakeup through EXTI line interrupt
    USBWAKE_UP = 58,
    ///59 - USBHD_IRQHandler
    USBHD = 59,
};

export fn microzig_interrupts_handler(mcause: u32) void {
    if (@hasDecl(root, "microzig_options") and @hasDecl(root.microzig_options, "interrupts")) {
        const interrupt_handlers = root.microzig_options.interrupts;
        if (@typeInfo(interrupt_handlers) != .Struct)
            @compileError("root.interrupts must be a struct");

        inline for (@typeInfo(interrupt_handlers).Struct.decls) |decl| {
            const handler = @field(interrupt_handlers, decl.name);
            // test handler is functio
            if (@typeInfo(@TypeOf(handler)) != .Fn)
                @compileError("Declarations in 'interrupts' namespace must all be functions. '" ++ handler.name ++ "' is not a function");

            if (@hasField(Interrupts, decl.name)) {
                if (@as(Interrupts, @enumFromInt(mcause)) == @field(Interrupts, decl.name)) handler();
            } else @compileError("No interrupt as " ++ decl.name);
        }
    }
}
