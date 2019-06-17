module board_connections (
  input CLK,
  input PIN_14, //SPI CLK
  input PIN_15, //SPI MOSI
  input PIN_16, //SPI SS
  output USBPU,
  output PIN_13,
  output PIN_12
);
  assign USBPU = 0;

  servo_controller servo_c(
    .i_clock (CLK),
    .i_spi_clock (PIN_14),
    .i_mosi (PIN_15),
    .i_select (PIN_16),
    .o_pwm ({PIN_13, PIN_12})
  );

endmodule

module servo_controller(
  input i_clock,
  input i_spi_clock,
  input i_mosi,
  input i_select,
  output [0:1] o_pwm
);

  wire [7:0] r_spiByte;
  reg [1:0] r_state = 0;

  wire w_newByte;
  reg r_newByte = 0;

  reg [7:0] r_index = 0;
  reg [15:0] r_pulse[0:1];// = 1500;
  reg [15:0] r_period = 20000;

  always @ (posedge i_clock) begin
    //as long as the FPGA clock is faster than the SPI i_clock
    //this should work
    if(r_newByte != w_newByte) begin
      case (r_state)
        0: r_index = r_spiByte;
        1: r_pulse[r_index][15:8] = r_spiByte;
        2: r_pulse[r_index][7:0] = r_spiByte;
      endcase
      r_state = r_state + 1;
      if(r_state == 3) begin
        r_state = 0;
      end
      r_newByte = w_newByte;
    end
  end

  spi spi_instance(
    .i_clock (i_spi_clock),
    .i_dataIn (i_mosi),
    .i_select (i_select),
    .o_dataByte (r_spiByte),
    .o_newByte (w_newByte)
  );

  generate
    genvar i;
    for(i=0;i<2;i=i+1) begin
      pwm_gen pwm(
        .i_clock (i_clock),
        .i_pulse (r_pulse[i]),
        .i_period (r_period),
        .o_pwm (o_pwm[i])
      );
    end
  endgenerate

endmodule

module pwm_gen(
  input i_clock,
  input [15:0] i_pulse,
  input [15:0] i_period,
  output reg o_pwm
);

  localparam clks_per_tick = 16; //16MHz/1000000 = 1us
  reg [7:0] r_ticks;
  reg [15:0] r_count;

  always @ (posedge i_clock) begin
    r_ticks = r_ticks+1;

    if(r_ticks == clks_per_tick) begin
      r_count = r_count+1;
      if(r_count == i_pulse) begin
        o_pwm = 0;
      end
      if(r_count == i_period) begin
        o_pwm = 1;
        r_count = 0;
      end
      r_ticks = 0;
    end
  end

endmodule

//implements CPOL = 1, CPHA = 0
//receive only
module spi(
  input i_clock,
  input i_dataIn,
  input i_select,
  output reg [7:0] o_dataByte = 0,
  output reg o_newByte = 0
);

  reg [2:0] r_bit = 0;
  reg [7:0] r_buffer = 0;

  always @ (negedge i_clock) begin
    if(~i_select) begin
      r_buffer[r_bit] = i_dataIn;
  	  r_bit = r_bit + 1;
    end
    if(r_bit == 7) begin
      //copy to output buffer
      o_dataByte = r_buffer;

      //toggle when new byte received
      o_newByte = !o_newByte;
    end
  end

endmodule
