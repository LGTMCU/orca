#ifndef SPI_H
#define SPI_H

#define FLASH_BASE ((volatile int*) 0x01000000) 

// Register Addresses
#define CR2_ADDR   ((volatile int*) (0x01000000 + (0x2A << 2))) 
#define TX_ADR     ((volatile int*) (0x01000000 + (0x2D << 2)))
#define RX_ADR     ((volatile int*) (0x01000000 + (0x2E << 2)))
#define SR_ADR     ((volatile int*) (0x01000000 + (0x2C << 2)))

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


unsigned int get_id(void) {
  
  unsigned char buffer[20] = {0};
  int i = 0;
  // Start frame.
  *CR2_ADDR = FRAME_I;
  // Wait for TRDY.
  while(!((*SR_ADR) & TRDY_M)); 

  // Add write data to TX.
  *TX_ADR = READ_ID;
  // Wait for RRDY.
  while(!((*SR_ADR) & RRDY_M));
  // Read and discard RRDY.


  // Add blank data to TX.
  // Wait for RRDY.
  // Collect output data.



}



#endif
