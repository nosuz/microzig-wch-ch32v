pub fn enable_interrupt() void {
    asm volatile ("csrwi mstatus, (1 << 3)" ::: "");
}

pub fn disable_interrupt() void {
    asm volatile ("csrr t0, mstatus" ::: "");
    // asm volatile ("andi t0, t0, 0xFFFFFFF7" ::: "");
    asm volatile ("andi t0, t0, ~(1 << 3)" ::: "");
    asm volatile ("csrw mstatus, t0" ::: "");
}

pub const Interrupts_ch32v203 = enum(u7) {
    /// Delived from Rust CH32V203 PAC
    /// https://raw.githubusercontent.com/ch32-rs/ch32-rs-nightlies/main/ch32v2/src/ch32v20x/mod.rs
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
    DMA1_CHANNEL1 = 27,
    ///28 - DMA1 Channel2 global interrupt
    DMA1_CHANNEL2 = 28,
    ///29 - DMA1 Channel3 global interrupt
    DMA1_CHANNEL3 = 29,
    ///30 - DMA1 Channel4 global interrupt
    DMA1_CHANNEL4 = 30,
    ///31 - DMA1 Channel5 global interrupt
    DMA1_CHANNEL5 = 31,
    ///32 - DMA1 Channel6 global interrupt
    DMA1_CHANNEL6 = 32,
    ///33 - DMA1 Channel7 global interrupt
    DMA1_CHANNEL7 = 33,
    ///34 - ADC global interrupt
    ADC = 34,
    ///35 - CAN1 TX interrupts
    USB_HP_CAN1_TX = 35,
    ///36 - CAN1 RX0 interrupts
    USB_LP_CAN1_RX0 = 36,
    ///37 - CAN1 RX1 interrupt
    CAN1_RX1 = 37,
    ///38 - CAN1 SCE interrupt
    CAN1_SCE = 38,
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
    ///58 - USB Device WakeUp from suspend through EXTI Line Interrupt
    USBWAKE_UP = 58,
    ///59 - TIM8 Break interrupt
    TIM8_BRK = 59,
    ///60 - TIM8 Update interrupt
    TIM8_UP = 60,
    ///61 - TIM8 Trigger and Commutation interrupts
    TIM8_TRG_COM = 61,
    ///62 - TIM8 Capture Compare interrupt
    TIM8_CC = 62,
    ///66 - TIM5 global interrupt
    TIM5 = 66,
    ///67 - SPI3 global interrupt
    SPI3 = 67,
    ///68 - UART4 global interrupt
    UART4 = 68,
    ///69 - UART5 global interrupt
    UART5 = 69,
    ///77 - Ethernet global interrupt
    ETH = 77,
    ///78 - Ethernet Wakeup through EXTI line interrupt
    ETH_WKUP = 78,
    ///83 - OTG_FS
    OTG_FS = 83,
    ///84 - USBHSWakeup
    USBHSWAKEUP = 84,
    ///85 - USBHS
    USBHS = 85,
    ///87 - UART6 global interrupt
    UART6 = 87,
    ///88 - UART7 global interrupt
    UART7 = 88,
    ///89 - UART8 global interrupt
    UART8 = 89,
    ///90 - TIM9 Break interrupt
    TIM9_BRK = 90,
    ///91 - TIM9 Update interrupt
    TIM9_UP = 91,
    ///92 - TIM9 Trigger and Commutation interrupts
    TIM9_TRG_COM = 92,
    ///93 - TIM9 Capture Compare interrupt
    TIM9_CC = 93,
    ///94 - TIM10 Break interrupt
    TIM10_BRK = 94,
    ///95 - TIM10 Update interrupt
    TIM10_UP = 95,
    ///96 - TIM10 Trigger and Commutation interrupts
    TIM10_TRG_COM = 96,
    ///97 - TIM10 Capture Compare interrupt
    TIM10_CC = 97,
};
