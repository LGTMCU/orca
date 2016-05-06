#include "printf.h"


#define SYS_CLK 12000000
volatile int *ledrgb= (volatile int*)0x10000;

/********/
/* GPIO */
/********/
volatile int *gpio_data= (volatile int*)0x30000;
volatile int *gpio_ctrl= (volatile int*)0x30004;
//////////////////////
//
// UART stuff
//////////////////////
#define  UART_BASE ((volatile int*) 0x00020000)
volatile int*  UART_DATA=UART_BASE;
volatile int*  UART_LCR=UART_BASE+3;
volatile int*  UART_LSR=UART_BASE+5;

#define UART_LCR_8BIT_DEFAULT 0x03
#define UART_INIT() do{*UART_LCR = UART_LCR_8BIT_DEFAULT;}while(0)
#define UART_PUTC(c) do{*UART_DATA = (c);}while(0)
#define UART_BUSY() (!((*UART_LSR) &0x20))
void mputc ( void* p, char c)
{
	while(UART_BUSY());
	*UART_DATA = c;
}
#define debug(var) printf("%s:%d  %s = %d \r\n",__FILE__,__LINE__,#var,(signed)(var))
#define debugx(var) printf("%s:%d  %s = %08X \r\n",__FILE__,__LINE__,#var,(unsigned)(var))

////////////
//TIMER   //
////////////
static inline unsigned get_time()
{int tmp;       asm volatile(" csrr %0,time":"=r"(tmp));return tmp;}

void delayus(int us)
{
	unsigned start=get_time();
	us*=(SYS_CLK/1000000);
	while(get_time()-start < us);
}
#define delayms(ms) delayus(ms*1000)

#define FLASH_BASE ((volatile int*) 0x01000000) 
#define FLASH_MEM  ((volatile int*) 0x01200000)
#define FLASH_END  ((volatile int*) 0x02000000)
#define WORD_SIZE 4
int main(void)
{
  unsigned int data;
  unsigned int address = 0;
  unsigned int index = 0;
  
  // Lower the LED intensity.
  *ledrgb = 0x0F0F0F;
  
  UART_INIT();
  init_printf(0, mputc);
  printf("top_bitmap.hex\r\n");
  while((FLASH_BASE + address) < FLASH_END) {
    data = *(FLASH_BASE + address);
    address += WORD_SIZE; 
    printf("%08x\n", data);
  }
  return 1;

  while(index < 10) {
    printf("Hello %d\r\n", index);
    index += 1;
    delayms(500);
  }
  while ((FLASH_MEM + address) < FLASH_END) {
    data = *(FLASH_BASE + address);
    printf("Address: %08x Data: %08x", (unsigned int)(FLASH_MEM+address), data);
    address += 4;
  }
  index = 100;
  while(1) {
    printf("Hello %d\r\n", index);
    index += 1;
    delayms(500);
  }
  return 1;
}


int handle_trap(long cause,long epc, long regs[32])
{
	//spin forever
	for(;;);
}
