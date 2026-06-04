#define uint32_t            unsigned int

#define SYS_ERR             -1
#define SYS_OK              0

#define APB_BRAM            0x10000000

#define APB_PERIPH_BASE     0x20000000
#define APB_GPO             (APB_PERIPH_BASE + 0x0000U)
#define APB_GPI             (APB_PERIPH_BASE + 0x1000U)
#define APB_GPIO            (APB_PERIPH_BASE + 0x2000U)
#define APB_FND             (APB_PERIPH_BASE + 0x3000U)
#define APB_UART            (APB_PERIPH_BASE + 0x4000U)

#define APB_GPO_CTL         (APB_GPO + 0x000U)
#define APB_GPO_ODATA       (APB_GPO + 0x004U)
#define APB_GPI_CTL         (APB_GPI + 0x000U)
#define APB_GPI_IDATA       (APB_GPI + 0x004U)
#define APB_GPIO_CTL        (APB_GPIO + 0x000U)
#define APB_GPIO_ODATA      (APB_GPIO + 0x004U)
#define APB_GPIO_IDATA      (APB_GPIO + 0x008U)
#define APB_FND_ODATA       (APB_FND + 0x000U)
#define APB_UART_CTL        (APB_UART + 0x000U)
#define APB_UART_BAUD       (APB_UART + 0x004U)
#define APB_UART_STATUS     (APB_UART + 0x008U)
#define APB_UART_TX_DATA    (APB_UART + 0x00CU)
#define APB_UART_RX_DATA    (APB_UART + 0x010U)

#define __IO                volatile

typedef struct {
    __IO uint32_t CTL;
    __IO uint32_t ODATA;
    __IO uint32_t IDATA;
} GPIO_TYPEDEF;

typedef struct {
    __IO uint32_t ODATA;
} FND_SECTION;

typedef struct {
    __IO uint32_t CTL;
    __IO uint32_t BAUD;
    __IO uint32_t STATUS;
    __IO uint32_t TX_DATA;
    __IO uint32_t RX_DATA;
} UART_SECTION;

#define GPIOA               ((GPIO_TYPEDEF *) APB_GPIO)
#define FNDA                ((unsigned int *) APB_FND)
#define UARTA               ((UART_SECTION *) APB_UART)

int sys_init(void);
void delay_ms(int delay);
void gpio_init(GPIO_TYPEDEF *GPIOx, unsigned int control);
void led_write(GPIO_TYPEDEF *GPIOx, unsigned int wdata);
unsigned int sw_read(GPIO_TYPEDEF *GPIOx);

void fnd_set_digit(unsigned int *FNDx, unsigned int digit);

int uart_baud_set(UART_SECTION* UARTx, unsigned int baud);
void uart_send(UART_SECTION* UARTx, char danAuh);
int uart_receive(UART_SECTION* UARTx, unsigned int *character);

int main(void) {
    unsigned int sw_in = 0;
    unsigned int input_value = 0;

    sys_init();

    uart_baud_set(UARTA, 2);
    uart_send(UARTA, '>');

    while (1){
        sw_in = sw_read(GPIOA);
        if ( (sw_in & 0x00000001) ) {
            // UART Signal Insert..
            if ( uart_receive(UARTA, &input_value) == 0 ) {
                led_write(GPIOA, (sw_in << 8) );
                uart_send(UARTA, (char) input_value);
                fnd_set_digit(FNDA, input_value);
            }
        }
        else {
            led_write(GPIOA, (sw_in << 8) );
            fnd_set_digit(FNDA, sw_in);
        }
    }

    return 0;
}

int sys_init(void) {
    int i = 0;

    // RAM
    *(unsigned int *) APB_BRAM = 0x00000000;
    i = *(unsigned int *) APB_BRAM;
    if (i != 0x00000000) {
        // UART_PRINT("SYS_ERR");
        return SYS_ERR;
    }
    
    // GPO
    *(unsigned int *) APB_GPO_CTL = 0x00000000;
    *(unsigned int *) APB_GPO_ODATA = 0x00000000;
    
    // GPI
    *(unsigned int *) APB_GPI_CTL = 0x00000000;
    i = *(unsigned int *) APB_GPI_IDATA;
    
    // GPIO
    *(unsigned int *) APB_GPIO_CTL = 0x00000000;
    *(unsigned int *) APB_GPIO_ODATA = 0x00000000;
    
    // FND
    *(unsigned int *) APB_FND_ODATA = 0x00000000;
    
    // UART
    *(unsigned int *) APB_UART_CTL = 0x00000000;
    *(unsigned int *) APB_UART_BAUD = 0x00000000;
    *(unsigned int *) APB_UART_TX_DATA = 0x00000000;
    
    gpio_init(GPIOA, 0x0000FF00);
    
    return 0;
}

void gpio_init(GPIO_TYPEDEF *GPIOx, unsigned int control){
    GPIOx->CTL = control;
}

void led_write(GPIO_TYPEDEF *GPIOx, unsigned int wdata){
    GPIOx->ODATA = wdata;
    return;
}

unsigned int sw_read(GPIO_TYPEDEF *GPIOx){
    return GPIOx->IDATA;
}

void fnd_set_digit(unsigned int *FNDx, unsigned int digit) {
    *FNDx = digit;
}

int uart_baud_set(UART_SECTION* UARTx, unsigned int baud) {
    UARTx->BAUD = baud;
    if ( (UARTx->BAUD) == baud ) return SYS_OK;
    return SYS_ERR;
}

void uart_send(UART_SECTION* UARTx, char danAuh) {
    unsigned int busy;
    
    do {
        busy = ( UARTx->STATUS ) & 0x00000001;
    } while(busy);
    
    UARTx->TX_DATA = (uint32_t) danAuh;
    UARTx->CTL = 0x00000001;
    UARTx->CTL = 0x00000000;

    do {
        busy = ( UARTx->STATUS ) & 0x00000001;
    } while(busy);
}

int uart_receive(UART_SECTION* UARTx, unsigned int *character) {
    int done;
    done = ( (UARTx->STATUS) & 0x80000000 ) >> 31;

    if (done) {
        *character = UARTx->RX_DATA;
        return SYS_OK;
    }

    return SYS_ERR;
}

