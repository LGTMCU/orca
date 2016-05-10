#include "spi.h"

void get_id(void) {

  unsigned char buffer[20] = {0};
  unsigned int read_buffer;
  int i = 0;

  // Start frame.
  *CR2_ADR = FRAME_I;
  // Wait for TRDY.
  while (!((*SR_ADR) & TRDY_M)); 
  printf("TRDY\r\n");
  // Add command to TX.
  *TX_ADR = READ_ID;
  // Wait for RRDY.
  while (!((*SR_ADR) & RRDY_M));  
  // Read and discard RRDY.
  read_buffer = *RX_ADR;
  for (i = 0; i < ID_LENGTH; i++) {
  // Add blank data to TX.
    *TX_ADR = DUMMY;
  // Wait for RRDY.
    while (!((*SR_ADR) & RRDY_M));
  // Collect output data.
    buffer[i] = (unsigned char)((*RX_ADR & 0xFF));
    printf("%02x\t%02x\r\n", i, buffer[i]);
  }
  // End frame.
  *CR2_ADR = FRAME_E;
  // Ensure transaction is complete
  while (!((*SR_ADR) & TIP_M));


}

void status(void) {
  printf("CR0 = %08x\r\n", *CR0_ADR);
  printf("CR1 = %08x\r\n", *CR1_ADR);
  printf("CR2 = %08x\r\n", *CR2_ADR);
  printf("BR  = %08x\r\n", *BR_ADR);
  printf("SR  = %08x\r\n", *SR_ADR);
  printf("TX  = %08x\r\n", *TX_ADR);
  printf("RX  = %08x\r\n", *RX_ADR);
  printf("CS  = %08x\r\n", *CS_ADR);
}
