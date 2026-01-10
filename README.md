# MAC-Forge
MAC-Forge is a Verilog HDL project that implements a systolic array based matrix multiplication engine. This project focuses on the fundamental building block: a parallel grid of Multiply-Accumulate (MAC) units.
# Overview on TPU's MMU
TPU features a weight stationary systolic array, meaning a set of weights may be loaded in once but used for many operations. The array is fully pipelined, performing a  
4 x 4 matrix multiply in just 8 (2n cycles for n x n matrix) cycles. It is composed of many processing elements (PEs), which contain a small amount of memory and control logic, and a single multiply accumulate data path. A complete Matrix Multiply starts at the top left corner of the Systolic array, and is piped diagonally downward. In the first cycle of a multiply, input memory supplies data for only the top left PE. After one cycle, the first PE activates its neighbors below and to the right, creating the diagonally downward piping.

<img width="1280" height="720" alt="image" src="https://github.com/user-attachments/assets/16c6b363-0fbd-4b2a-86b3-ba502e470e79" />

Each PE holds one element of the input matrix in any given cycle, and passes that element to its right neighbor every cycle. The multiply accumulate result is passed downward to the neighbor below every cycle. Each PE then multiplies its input element with the weight element stored in it, then adds that value to the sum being supplied from its above neighbor. Note that memory interfaces only exist at the edges of the systolic array. Multiplication results appear at the bottom of the systolic array 16 cycles after a multiplication is started, and continue flowing out for 16 cycles. The flow of data is illustrated below, showing a scaled down version of our systolic array

MAC'n'roll!

