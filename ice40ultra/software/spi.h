#ifndef SPI_H
#define SPI_H

#include "printf.h"

// Constants
#define ID_LENGTH  20
#define FLASH_BASE ((volatile int*) 0x01000000) 
#define FLASH_END  ((volatile int*) 0x02000000)

// Register Addresses
#define CR0_ADR    ((volatile int*) (0x01000000 + (0x28 << 2)))
#define CR1_ADR    ((volatile int*) (0x01000000 + (0x29 << 2)))
#define CR2_ADR    ((volatile int*) (0x01000000 + (0x2A << 2))) 
#define BR_ADR     ((volatile int*) (0x01000000 + (0x2B << 2)))
#define SR_ADR     ((volatile int*) (0x01000000 + (0x2C << 2)))
#define TX_ADR     ((volatile int*) (0x01000000 + (0x2D << 2)))
#define RX_ADR     ((volatile int*) (0x01000000 + (0x2E << 2)))
#define CS_ADR     ((volatile int*) (0x01000000 + (0x2F << 2)))



// Register Values
#define FRAME_I     0xC0
#define FRAME_E     0x80
#define DUMMY       0x00

// Byte Masks
#define TRDY_M     (unsigned int) (0x00000010) // 4
#define RRDY_M     (unsigned int) (0x00000008) // 3
#define TIP_M      (unsigned int) (0x00000080) // 7

// Commands
#define READ_ID     0x9E
#define READ        0x03


void get_id(void);
void status(void);

#endif
