#include "spi.h"

void get_id(void) {

  unsigned char buffer[20] = {0};
  unsigned int read_buffer;
  unsigned int status_buffer;
  int i = 0;

  // Start frame.
  *CR2_ADR = FRAME_I;
  // Wait for TRDY.
  while (!((*SR_ADR) & TRDY_M)); 
  printf("Status 1:\r\n");
  status();
  // Add command to TX.
  *TX_ADR = READ_ID;
  printf("Status 2:\r\n");
  status();
  // Wait for RRDY.
  while (!((*SR_ADR) & RRDY_M));  
  printf("Status 3:\r\n");
  status();
  // Read and discard RRDY.
  while(*SR_ADR & RRDY_M) {
    read_buffer = *RX_ADR;
    printf("Output: %d\r\n", read_buffer);
    printf("Status 4:\r\n");
    status();
  }
  for (i = 0; i < 2; i++) {
    printf("i = %d\r\n", i);
  // Add blank data to TX.
    *TX_ADR = DUMMY;
    printf("Status 5:\r\n");
    status();
  // Wait for RRDY.
    while (!((*SR_ADR) & RRDY_M));
    printf("Status 6:\r\n");
    status();
  // Collect output data.
    while (*SR_ADR & RRDY_M) {
      buffer[i] = (unsigned char)((*RX_ADR & 0xFF));
      printf("%02x\t%02x\r\n", i, buffer[i]);
      printf("Status 7:\r\n");
      status();
    }
  }
  // End frame.
  while (*SR_ADR & RRDY_M);
  *CR2_ADR = FRAME_E;

  //while (!(*SR_ADR & RRDY_M)) {
    //buffer[i] = (unsigned char)((*RX_ADR & 0xFF));
    //printf("%02x\t%02x\r\n", i, buffer[i]);
  status_buffer = *SR_ADR;
  if (!(status_buffer & RRDY_M)) {
    printf("2nd CR2 = %08x\r\n", *CR2_ADR);
    printf("Before CR2: %08x\r\n", status_buffer);
    printf("Status 8:\r\n");
    status();
    while (*SR_ADR & RRDY_M) {
      read_buffer = (unsigned char)((*RX_ADR & 0xFF));
      printf("%08x\r\n", read_buffer);
    }

  }
  //}
  printf("Status 9:\r\n");
  status();
  // Ensure transaction is complete
  while (!((*SR_ADR) & TIP_M));


}

void status(void) {
  printf("CR0 = %08x\r\n", *CR0_ADR);
  printf("CR1 = %08x\r\n", *CR1_ADR);
  printf("CR2 = %08x\r\n", *CR2_ADR);
  printf("BR  = %08x\r\n", *BR_ADR);
  printf("SR  = %08x\r\n", *SR_ADR);
  printf("CS  = %08x\r\n", *CS_ADR);
}
