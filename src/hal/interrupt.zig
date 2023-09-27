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

export fn microzig_interrupts_handler(mcause: u32) void {
    // Do I need to write all Interrupt names?
    switch (@as(Interrupts_ch32v203, @enumFromInt(mcause))) {
        Interrupts_ch32v203.WWDG => {
            if (@hasDecl(root.interrupt_handlers, "WWDG")) root.interrupt_handlers.WWDG();
        },
        Interrupts_ch32v203.PVD => {
            if (@hasDecl(root.interrupt_handlers, "PVD")) root.interrupt_handlers.PVD();
        },
        Interrupts_ch32v203.TAMPER => {
            if (@hasDecl(root.interrupt_handlers, "TAMPER")) root.interrupt_handlers.TAMPER();
        },
        Interrupts_ch32v203.RTC => {
            if (@hasDecl(root.interrupt_handlers, "RTC")) root.interrupt_handlers.RTC();
        },
        Interrupts_ch32v203.FLASH => {
            if (@hasDecl(root.interrupt_handlers, "FLASH")) root.interrupt_handlers.FLASH();
        },
        Interrupts_ch32v203.RCC => {
            if (@hasDecl(root.interrupt_handlers, "RCC")) root.interrupt_handlers.RCC();
        },
        Interrupts_ch32v203.EXTI0 => {
            if (@hasDecl(root.interrupt_handlers, "EXTI0")) root.interrupt_handlers.EXTI0();
        },
        Interrupts_ch32v203.EXTI1 => {
            if (@hasDecl(root.interrupt_handlers, "EXTI1")) root.interrupt_handlers.EXTI1();
        },
        Interrupts_ch32v203.EXTI2 => {
            if (@hasDecl(root.interrupt_handlers, "EXTI2")) root.interrupt_handlers.EXTI2();
        },
        Interrupts_ch32v203.EXTI3 => {
            if (@hasDecl(root.interrupt_handlers, "EXTI3")) root.interrupt_handlers.EXTI3();
        },
        Interrupts_ch32v203.EXTI4 => {
            if (@hasDecl(root.interrupt_handlers, "EXTI4")) root.interrupt_handlers.EXTI4();
        },
        Interrupts_ch32v203.DMA1_CHANNEL1 => {
            if (@hasDecl(root.interrupt_handlers, "DMA1_CHANNEL1")) root.interrupt_handlers.DMA1_CHANNEL1();
        },
        Interrupts_ch32v203.DMA1_CHANNEL2 => {
            if (@hasDecl(root.interrupt_handlers, "DMA1_CHANNEL2")) root.interrupt_handlers.DMA1_CHANNEL2();
        },
        Interrupts_ch32v203.DMA1_CHANNEL3 => {
            if (@hasDecl(root.interrupt_handlers, "DMA1_CHANNEL3")) root.interrupt_handlers.DMA1_CHANNEL3();
        },
        Interrupts_ch32v203.DMA1_CHANNEL4 => {
            if (@hasDecl(root.interrupt_handlers, "DMA1_CHANNEL4")) root.interrupt_handlers.DMA1_CHANNEL4();
        },
        Interrupts_ch32v203.DMA1_CHANNEL5 => {
            if (@hasDecl(root.interrupt_handlers, "DMA1_CHANNEL5")) root.interrupt_handlers.DMA1_CHANNEL5();
        },
        Interrupts_ch32v203.DMA1_CHANNEL6 => {
            if (@hasDecl(root.interrupt_handlers, "DMA1_CHANNEL6")) root.interrupt_handlers.DMA1_CHANNEL6();
        },
        Interrupts_ch32v203.DMA1_CHANNEL7 => {
            if (@hasDecl(root.interrupt_handlers, "DMA1_CHANNEL7")) root.interrupt_handlers.DMA1_CHANNEL7();
        },
        Interrupts_ch32v203.ADC => {
            if (@hasDecl(root.interrupt_handlers, "ADC")) root.interrupt_handlers.ADC();
        },
        Interrupts_ch32v203.USB_HP_CAN1_TX => {
            if (@hasDecl(root.interrupt_handlers, "USB_HP_CAN1_TX")) root.interrupt_handlers.USB_HP_CAN1_TX();
        },
        Interrupts_ch32v203.USB_LP_CAN1_RX0 => {
            if (@hasDecl(root.interrupt_handlers, "USB_LP_CAN1_RX0")) root.interrupt_handlers.USB_LP_CAN1_RX0();
        },
        Interrupts_ch32v203.CAN1_RX1 => {
            if (@hasDecl(root.interrupt_handlers, "CAN1_RX1")) root.interrupt_handlers.CAN1_RX1();
        },
        Interrupts_ch32v203.CAN1_SCE => {
            if (@hasDecl(root.interrupt_handlers, "CAN1_SCE")) root.interrupt_handlers.CAN1_SCE();
        },
        Interrupts_ch32v203.EXTI9_5 => {
            if (@hasDecl(root.interrupt_handlers, "EXTI9_5")) root.interrupt_handlers.EXTI9_5();
        },
        Interrupts_ch32v203.TIM1_BRK => {
            if (@hasDecl(root.interrupt_handlers, "TIM1_BRK")) root.interrupt_handlers.TIM1_BRK();
        },
        Interrupts_ch32v203.TIM1_UP => {
            if (@hasDecl(root.interrupt_handlers, "TIM1_UP")) root.interrupt_handlers.TIM1_UP();
        },
        Interrupts_ch32v203.TIM1_TRG_COM => {
            if (@hasDecl(root.interrupt_handlers, "TIM1_TRG_COM")) root.interrupt_handlers.TIM1_TRG_COM();
        },
        Interrupts_ch32v203.TIM1_CC => {
            if (@hasDecl(root.interrupt_handlers, "TIM1_CC")) root.interrupt_handlers.TIM1_CC();
        },
        Interrupts_ch32v203.TIM2 => {
            if (@hasDecl(root.interrupt_handlers, "TIM2")) root.interrupt_handlers.TIM2();
        },
        Interrupts_ch32v203.TIM3 => {
            if (@hasDecl(root.interrupt_handlers, "TIM3")) root.interrupt_handlers.TIM3();
        },
        Interrupts_ch32v203.TIM4 => {
            if (@hasDecl(root.interrupt_handlers, "TIM4")) root.interrupt_handlers.TIM4();
        },
        Interrupts_ch32v203.I2C1_EV => {
            if (@hasDecl(root.interrupt_handlers, "I2C1_EV")) root.interrupt_handlers.I2C1_EV();
        },
        Interrupts_ch32v203.I2C1_ER => {
            if (@hasDecl(root.interrupt_handlers, "I2C1_ER")) root.interrupt_handlers.I2C1_ER();
        },
        Interrupts_ch32v203.I2C2_EV => {
            if (@hasDecl(root.interrupt_handlers, "I2C2_EV")) root.interrupt_handlers.I2C2_EV();
        },
        Interrupts_ch32v203.I2C2_ER => {
            if (@hasDecl(root.interrupt_handlers, "I2C2_ER")) root.interrupt_handlers.I2C2_ER();
        },
        Interrupts_ch32v203.SPI1 => {
            if (@hasDecl(root.interrupt_handlers, "SPI1")) root.interrupt_handlers.SPI1();
        },
        Interrupts_ch32v203.SPI2 => {
            if (@hasDecl(root.interrupt_handlers, "SPI2")) root.interrupt_handlers.SPI2();
        },
        Interrupts_ch32v203.USART1 => {
            if (@hasDecl(root.interrupt_handlers, "USART1")) root.interrupt_handlers.USART1();
        },
        Interrupts_ch32v203.USART2 => {
            if (@hasDecl(root.interrupt_handlers, "USART2")) root.interrupt_handlers.USART2();
        },
        Interrupts_ch32v203.USART3 => {
            if (@hasDecl(root.interrupt_handlers, "USART3")) root.interrupt_handlers.USART3();
        },
        Interrupts_ch32v203.EXTI15_10 => {
            if (@hasDecl(root.interrupt_handlers, "EXTI15_10")) root.interrupt_handlers.EXTI15_10();
        },
        Interrupts_ch32v203.RTCALARM => {
            if (@hasDecl(root.interrupt_handlers, "RTCALARM")) root.interrupt_handlers.RTCALARM();
        },
        Interrupts_ch32v203.USBWAKE_UP => {
            if (@hasDecl(root.interrupt_handlers, "USBWAKE_UP")) root.interrupt_handlers.USBWAKE_UP();
        },
        Interrupts_ch32v203.TIM8_BRK => {
            if (@hasDecl(root.interrupt_handlers, "TIM8_BRK")) root.interrupt_handlers.TIM8_BRK();
        },
        Interrupts_ch32v203.TIM8_UP => {
            if (@hasDecl(root.interrupt_handlers, "TIM8_UP")) root.interrupt_handlers.TIM8_UP();
        },
        Interrupts_ch32v203.TIM8_TRG_COM => {
            if (@hasDecl(root.interrupt_handlers, "TIM8_TRG_COM")) root.interrupt_handlers.TIM8_TRG_COM();
        },
        Interrupts_ch32v203.TIM8_CC => {
            if (@hasDecl(root.interrupt_handlers, "TIM8_CC")) root.interrupt_handlers.TIM8_CC();
        },
        Interrupts_ch32v203.TIM5 => {
            if (@hasDecl(root.interrupt_handlers, "TIM5")) root.interrupt_handlers.TIM5();
        },
        Interrupts_ch32v203.SPI3 => {
            if (@hasDecl(root.interrupt_handlers, "SPI3")) root.interrupt_handlers.SPI3();
        },
        Interrupts_ch32v203.UART4 => {
            if (@hasDecl(root.interrupt_handlers, "UART4")) root.interrupt_handlers.UART4();
        },
        Interrupts_ch32v203.UART5 => {
            if (@hasDecl(root.interrupt_handlers, "UART5")) root.interrupt_handlers.UART5();
        },
        Interrupts_ch32v203.ETH => {
            if (@hasDecl(root.interrupt_handlers, "ETH")) root.interrupt_handlers.ETH();
        },
        Interrupts_ch32v203.ETH_WKUP => {
            if (@hasDecl(root.interrupt_handlers, "ETH_WKUP")) root.interrupt_handlers.ETH_WKUP();
        },
        Interrupts_ch32v203.OTG_FS => {
            if (@hasDecl(root.interrupt_handlers, "OTG_FS")) root.interrupt_handlers.OTG_FS();
        },
        Interrupts_ch32v203.USBHSWAKEUP => {
            if (@hasDecl(root.interrupt_handlers, "USBHSWAKEUP")) root.interrupt_handlers.USBHSWAKEUP();
        },
        Interrupts_ch32v203.USBHS => {
            if (@hasDecl(root.interrupt_handlers, "USBHS")) root.interrupt_handlers.USBHS();
        },
        Interrupts_ch32v203.UART6 => {
            if (@hasDecl(root.interrupt_handlers, "UART6")) root.interrupt_handlers.UART6();
        },
        Interrupts_ch32v203.UART7 => {
            if (@hasDecl(root.interrupt_handlers, "UART7")) root.interrupt_handlers.UART7();
        },
        Interrupts_ch32v203.UART8 => {
            if (@hasDecl(root.interrupt_handlers, "UART8")) root.interrupt_handlers.UART8();
        },
        Interrupts_ch32v203.TIM9_BRK => {
            if (@hasDecl(root.interrupt_handlers, "TIM9_BRK")) root.interrupt_handlers.TIM9_BRK();
        },
        Interrupts_ch32v203.TIM9_UP => {
            if (@hasDecl(root.interrupt_handlers, "TIM9_UP")) root.interrupt_handlers.TIM9_UP();
        },
        Interrupts_ch32v203.TIM9_TRG_COM => {
            if (@hasDecl(root.interrupt_handlers, "TIM9_TRG_COM")) root.interrupt_handlers.TIM9_TRG_COM();
        },
        Interrupts_ch32v203.TIM9_CC => {
            if (@hasDecl(root.interrupt_handlers, "TIM9_CC")) root.interrupt_handlers.TIM9_CC();
        },
        Interrupts_ch32v203.TIM10_BRK => {
            if (@hasDecl(root.interrupt_handlers, "TIM10_BRK")) root.interrupt_handlers.TIM10_BRK();
        },
        Interrupts_ch32v203.TIM10_UP => {
            if (@hasDecl(root.interrupt_handlers, "TIM10_UP")) root.interrupt_handlers.TIM10_UP();
        },
        Interrupts_ch32v203.TIM10_TRG_COM => {
            if (@hasDecl(root.interrupt_handlers, "TIM10_TRG_COM")) root.interrupt_handlers.TIM10_TRG_COM();
        },
        Interrupts_ch32v203.TIM10_CC => {
            if (@hasDecl(root.interrupt_handlers, "TIM10_CC")) root.interrupt_handlers.TIM10_CC();
        },
    }
}
