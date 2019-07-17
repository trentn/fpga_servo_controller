module board_connections (
  input CLK,
  input PIN_14, //SPI CLK
  input PIN_15, //SPI MOSI
  input PIN_16, //SPI SS
  output USBPU,
  output PIN_2,
  output PIN_3,
  output PIN_4,
  output PIN_5,
  output PIN_6,
  output PIN_7,
  output PIN_8,
  output PIN_9,
  output PIN_10,
  output PIN_11,
  output PIN_12,
  output PIN_13
);
  assign USBPU = 0;

  servo_controller servo_c(
    .i_clock (CLK),
    .i_spi_clock (PIN_14),
    .i_mosi (PIN_15),
    .i_select (PIN_16),
    .o_pwm ({PIN_2, PIN_3, PIN_4,
             PIN_5, PIN_6, PIN_7,
             PIN_8, PIN_9, PIN_10,
             PIN_11, PIN_12, PIN_13})
  );

endmodule

//Main logic module
//can group pins for loop by having a
  //separate board connections module
module servo_controller(

  input i_clock,
  input i_spi_clock,
  input i_mosi,
  input i_select,
  output [0:11] o_pwm
);

  wire [7:0] r_spiByte;
  reg [1:0] r_state = 0;

  wire w_newByte;
  reg r_newByte = 0;

  reg [7:0] r_index = 0;
  reg [15:0] r_pulse[0:11];// = 1500;
  reg [15:0] r_buffer;
  reg [15:0] r_period = 20000;


  //SPI logic
  //implements CPOL = 1, CPHA = 0
  //receive only
  //having the code here instead of initial begin
    //a separate module means synchronization issues
    //can be avoided
  reg [2:0] r_bit = 0;
  reg [7:0] r_SPIbuffer = 0;
  always @ (negedge i_spi_clock) begin
    if(~i_select) begin
      r_SPIbuffer[r_bit] = i_mosi;
      if(r_bit == 7) begin
        case (r_state)
          0: r_index = r_SPIbuffer;
          1: r_buffer[15:8] = r_SPIbuffer;
          2: r_buffer[7:0] = r_SPIbuffer;
        endcase
        r_state = r_state + 1;
        if(r_state == 3) begin
           r_pulse[r_index] = r_buffer;
           r_state = r_state + 1;
        end
      end
  	  r_bit = r_bit + 1;
    end
  end

  //create a pwm generator for each servo being controlled
  generate
    genvar i;
      for(i=0;i<12;i=i+1) begin
      pwm_gen pwm(
        .i_clock (i_clock),
        .i_pulse (r_pulse[i]),
        .i_period (r_period),
        .o_pwm (o_pwm[i])
      );
     end
  endgenerate

endmodule


//PWM generator module
module pwm_gen(
  input i_clock,
  input wire [15:0] i_pulse,
  input wire [15:0] i_period,
  output reg o_pwm = 1
);

  reg [7:0] r_ticks = 0;
  reg [15:0] r_count = 0;

  always @ (posedge i_clock) begin
    r_ticks = r_ticks+1;

    if(r_ticks > 15) begin
      r_count = r_count+1;
      if(r_count > i_pulse) begin
        o_pwm = 0;
      end
      if(r_count > i_period) begin
        o_pwm = 1;
        r_count = 0;
      end
      r_ticks = 0;
    end
  end

endmodule
