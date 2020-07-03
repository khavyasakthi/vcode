`define clk_period 100

module logistic(
input clk
);

wire  [31:0]    mul_out,sub_out;

reg  [31:0] a_m, b_m, a_s, b_s, a_m1, b_m1;
reg  [31:0]log_val[81:0];
reg  [31:0]logistic_values       [81:0];

wire [31:0]check_logistic_values [81:0];


wire [31:0]out;
reg  [1:0] state;
integer i = 0;
integer k = 0;
integer l = 0;
integer j = 0;
integer count = 1;

  

initial begin
 log_val[0] = 32'b00111111010010100001110010101100;  // Pass Single precision IEEE-754 format float value (initial condition X_0=0.7894)
end


parameter s0 = 0;
parameter s1 = 1;
parameter s2 = 2;

always@(posedge clk)
begin
 case(state)
  s0 :state <= s1;
  s1 :state <= s2;
  s2 :state <= s0;
  default :  state <=s0;
endcase
end


always@(state)
begin
 case(state)
 s0: begin
     a_m = 32'b01000000011111001100110011001101;     // Pass Single precision IEEE-754 format float value (here r=3.95)
     b_m = log_val[i];
     a_s = 32'b00111111100000000000000000000000;
     b_s = log_val[i];
     i = i + 1;
    end

 s1: begin
     a_m1 = mul_out;
     b_m1 = sub_out;
     i = i + 1;
     end

 s2: begin
     log_val[i] = out;
     end
 endcase
end


Multiplication m1(.a_operand(a_m), .b_operand(b_m),  .result(mul_out));
subtraction s7(.a_operand(a_s), .b_operand(b_s), .AddBar_Sub(1'b1),  .result(sub_out));
Multiplication m2(.a_operand(a_m1), .b_operand(b_m1),  .result(out));


always@(out) begin
  logistic_values[count]=out;
  count = count+1;
end




genvar i1;
for(i1=0;i1<82;i1=i1+1)begin
 assign check_logistic_values[i1]  = logistic_values[i1];  // the generated logistic are obtained in check_logistic_values.
end

endmodule





module subtraction(

input [31:0] a_operand,b_operand, //Inputs in the format of IEEE-754 Representation.
input AddBar_Sub,	          //If Add_Sub is low then Addition else Subtraction.
output [31:0] result              //Outputs in the format of IEEE-754 Representation.
);

wire operation_sub_addBar;
wire Comp_enable;
wire output_sign;
wire Exception,
wire [31:0] operand_a,operand_b;
wire [23:0] significand_a,significand_b;
wire [7:0] exponent_diff;


wire [23:0] significand_b_add_sub;
wire [7:0] exponent_b_add_sub;

wire [24:0] significand_add;
wire [30:0] add_sum;

wire [23:0] significand_sub_complement;
wire [24:0] significand_sub;
wire [30:0] sub_diff;
wire [24:0] subtraction_diff; 
wire [7:0] exponent_sub;

//for operations always operand_a must not be less than b_operand
assign {Comp_enable,operand_a,operand_b} = (a_operand[30:0] < b_operand[30:0]) ? {1'b1,b_operand,a_operand} : {1'b0,a_operand,b_operand};

assign exp_a = operand_a[30:23];
assign exp_b = operand_b[30:23];

//Exception flag sets 1 if either one of the exponent is 255.
assign Exception = (&operand_a[30:23]) | (&operand_b[30:23]);

assign output_sign = AddBar_Sub ? Comp_enable ? !operand_a[31] : operand_a[31] : operand_a[31] ;

assign operation_sub_addBar = AddBar_Sub ? operand_a[31] ^ operand_b[31] : ~(operand_a[31] ^ operand_b[31]);

//Assigining significand values according to Hidden Bit.
//If exponent is equal to zero then hidden bit will be 0 for that respective significand else it will be 1
assign significand_a = (|operand_a[30:23]) ? {1'b1,operand_a[22:0]} : {1'b0,operand_a[22:0]};
assign significand_b = (|operand_b[30:23]) ? {1'b1,operand_b[22:0]} : {1'b0,operand_b[22:0]};

//Evaluating Exponent Difference
assign exponent_diff = operand_a[30:23] - operand_b[30:23];

//Shifting significand_b according to exponent_diff
assign significand_b_add_sub = significand_b >> exponent_diff;

assign exponent_b_add_sub = operand_b[30:23] + exponent_diff; 

//Checking exponents are same or not
assign perform = (operand_a[30:23] == exponent_b_add_sub);

///////////////////////////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------ADD BLOCK------------------------------------------//

assign significand_add = (perform & operation_sub_addBar) ? (significand_a + significand_b_add_sub) : 25'd0; 

//Result will be equal to Most 23 bits if carry generates else it will be Least 22 bits.
assign add_sum[22:0] = significand_add[24] ? significand_add[23:1] : significand_add[22:0];

//If carry generates in sum value then exponent must be added with 1 else feed as it is.
assign add_sum[30:23] = significand_add[24] ? (1'b1 + operand_a[30:23]) : operand_a[30:23];

///////////////////////////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------SUB BLOCK------------------------------------------//

assign significand_sub_complement = (perform & !operation_sub_addBar) ? ~(significand_b_add_sub) + 24'd1 : 24'd0 ; 

assign significand_sub = perform ? (significand_a + significand_sub_complement) : 25'd0;

priority_encoder pe(significand_sub,operand_a[30:23],subtraction_diff,exponent_sub);

assign sub_diff[30:23] = exponent_sub;

assign sub_diff[22:0] = subtraction_diff[22:0];

///////////////////////////////////////////////////////////////////////////////////////////////////////
//-------------------------------------------------OUTPUT--------------------------------------------//

//If there is no exception and operation will evaluate


assign result = Exception ? 32'b0 : ((!operation_sub_addBar) ? {output_sign,sub_diff} : {output_sign,add_sum});

endmodule













module Multiplication(
		input [31:0] a_operand,
		input [31:0] b_operand,
		
		output [31:0] result
		);

wire sign,product_round,normalised,zero;
wire [8:0] exponent,sum_exponent;
wire [22:0] product_mantissa;
wire [23:0] operand_a,operand_b;
wire [47:0] product,product_normalised; //48 Bits
wire Exception,Overflow,Underflow;

assign sign = a_operand[31] ^ b_operand[31];

//Exception flag sets 1 if either one of the exponent is 255.
assign Exception = (&a_operand[30:23]) | (&b_operand[30:23]);

//Assigining significand values according to Hidden Bit.
//If exponent is equal to zero then hidden bit will be 0 for that respective significand else it will be 1

assign operand_a = (|a_operand[30:23]) ? {1'b1,a_operand[22:0]} : {1'b0,a_operand[22:0]};

assign operand_b = (|b_operand[30:23]) ? {1'b1,b_operand[22:0]} : {1'b0,b_operand[22:0]};

assign product = operand_a * operand_b;			//Calculating Product

assign product_round = |product_normalised[22:0];  //Ending 22 bits are OR'ed for rounding operation.

assign normalised = product[47] ? 1'b1 : 1'b0;	

assign product_normalised = normalised ? product : product << 1;	//Assigning Normalised value based on 48th bit

//Final Manitssa.
assign product_mantissa = product_normalised[46:24] + (product_normalised[23] & product_round); 

assign zero = Exception ? 1'b0 : (product_mantissa == 23'd0) ? 1'b1 : 1'b0;

assign sum_exponent = a_operand[30:23] + b_operand[30:23];

assign exponent = sum_exponent - 8'd127 + normalised;

assign Overflow = ((exponent[8] & !exponent[7]) & !zero) ; //If overall exponent is greater than 255 then Overflow condition.
//Exception Case when exponent reaches its maximu value that is 384.

//If sum of both exponents is less than 127 then Underflow condition.
assign Underflow = ((exponent[8] & exponent[7]) & !zero) ? 1'b1 : 1'b0; 

assign result = Exception ? 32'd0 : zero ? {sign,31'd0} : Overflow ? {sign,8'hFF,23'd0} : Underflow ? {sign,31'd0} : {sign,exponent[7:0],product_mantissa};


endmodule





module priority_encoder(
			input [24:0] significand,
			input [7:0] Exponent_a,
			output reg [24:0] Significand,
			output [7:0] Exponent_sub
			);

reg [4:0] shift;

always @(significand)
begin
	casex (significand)
		25'b1_1xxx_xxxx_xxxx_xxxx_xxxx_xxxx :	begin
													Significand = significand;
									 				shift = 5'd0;
								 			  	end
		25'b1_01xx_xxxx_xxxx_xxxx_xxxx_xxxx : 	begin						
										 			Significand = significand << 1;
									 				shift = 5'd1;
								 			  	end

		25'b1_001x_xxxx_xxxx_xxxx_xxxx_xxxx : 	begin						
										 			Significand = significand << 2;
									 				shift = 5'd2;
								 				end

		25'b1_0001_xxxx_xxxx_xxxx_xxxx_xxxx : 	begin 							
													Significand = significand << 3;
								 	 				shift = 5'd3;
								 				end

		25'b1_0000_1xxx_xxxx_xxxx_xxxx_xxxx : 	begin						
									 				Significand = significand << 4;
								 	 				shift = 5'd4;
								 				end

		25'b1_0000_01xx_xxxx_xxxx_xxxx_xxxx : 	begin						
									 				Significand = significand << 5;
								 	 				shift = 5'd5;
								 				end

		25'b1_0000_001x_xxxx_xxxx_xxxx_xxxx : 	begin						// 24'h020000
									 				Significand = significand << 6;
								 	 				shift = 5'd6;
								 				end

		25'b1_0000_0001_xxxx_xxxx_xxxx_xxxx : 	begin						// 24'h010000
									 				Significand = significand << 7;
								 	 				shift = 5'd7;
								 				end

		25'b1_0000_0000_1xxx_xxxx_xxxx_xxxx : 	begin						// 24'h008000
									 				Significand = significand << 8;
								 	 				shift = 5'd8;
								 				end

		25'b1_0000_0000_01xx_xxxx_xxxx_xxxx : 	begin						// 24'h004000
									 				Significand = significand << 9;
								 	 				shift = 5'd9;
								 				end

		25'b1_0000_0000_001x_xxxx_xxxx_xxxx : 	begin						// 24'h002000
									 				Significand = significand << 10;
								 	 				shift = 5'd10;
								 				end

		25'b1_0000_0000_0001_xxxx_xxxx_xxxx : 	begin						// 24'h001000
									 				Significand = significand << 11;
								 	 				shift = 5'd11;
								 				end

		25'b1_0000_0000_0000_1xxx_xxxx_xxxx : 	begin						// 24'h000800
									 				Significand = significand << 12;
								 	 				shift = 5'd12;
								 				end

		25'b1_0000_0000_0000_01xx_xxxx_xxxx : 	begin						// 24'h000400
									 				Significand = significand << 13;
								 	 				shift = 5'd13;
								 				end

		25'b1_0000_0000_0000_001x_xxxx_xxxx : 	begin						// 24'h000200
									 				Significand = significand << 14;
								 	 				shift = 5'd14;
								 				end

		25'b1_0000_0000_0000_0001_xxxx_xxxx  : 	begin						// 24'h000100
									 				Significand = significand << 15;
								 	 				shift = 5'd15;
								 				end

		25'b1_0000_0000_0000_0000_1xxx_xxxx : 	begin						// 24'h000080
									 				Significand = significand << 16;
								 	 				shift = 5'd16;
								 				end

		25'b1_0000_0000_0000_0000_01xx_xxxx : 	begin						// 24'h000040
											 		Significand = significand << 17;
										 	 		shift = 5'd17;
												end

		25'b1_0000_0000_0000_0000_001x_xxxx : 	begin						// 24'h000020
									 				Significand = significand << 18;
								 	 				shift = 5'd18;
								 				end

		25'b1_0000_0000_0000_0000_0001_xxxx : 	begin						// 24'h000010
									 				Significand = significand << 19;
								 	 				shift = 5'd19;
												end

		25'b1_0000_0000_0000_0000_0000_1xxx :	begin						// 24'h000008
									 				Significand = significand << 20;
								 					shift = 5'd20;
								 				end

		25'b1_0000_0000_0000_0000_0000_01xx : 	begin						// 24'h000004
									 				Significand = significand << 21;
								 	 				shift = 5'd21;
								 				end

		25'b1_0000_0000_0000_0000_0000_001x : 	begin						// 24'h000002
									 				Significand = significand << 22;
								 	 				shift = 5'd22;
								 				end

		25'b1_0000_0000_0000_0000_0000_0001 : 	begin						// 24'h000001
									 				Significand = significand << 23;
								 	 				shift = 5'd23;
								 				end

		25'b1_0000_0000_0000_0000_0000_0000 : 	begin						// 24'h000000
								 					Significand = significand << 24;
							 	 					shift = 5'd24;
								 				end
		default : 	begin
						Significand = (~significand) + 1'b1;
						shift = 8'd0;
					end

	endcase
end
assign Exponent_sub = Exponent_a - shift;

endmodule









module main(a,b,y,clk);
input [31:0]a;
input [31:0]b;
output [31:0]y;
input clk;
wire cout;
wire [7:0]b1,b2,y1;
wire [7:0]op_rc;
reg [7:0]y2,count;
wire [31:0]data_in;

initial begin
 count = -1;
end

always @(posedge clk)
begin
 if (count == 27)
  begin
  if(a[22] && b[22])
   y2 = y1 + 1'b1;
  else
   y2 = y1; 
   count <= -1;
  end
 else
  count = count;
 count = count + 1;
end

assign y[30:23] = y2;
assign y[31] = a[31] ^ b[31];
bias b11(a[30:23] , b1);
bias b21(b[30:23] , b2);
ripple_carry_8_bit v1(b1, b2, 1'b0, op_rc, cout);
biaspos d1(op_rc , y1[7:0]);
multiplier m1(y[22:0], a[22:0], b[22:0], clk);
synchronizer z1(.data_in(data_in), .a(a), .b(b), .clk(clk));
endmodule



module bias(a,b);
input [7:0]a;
output [7:0]b;
  assign b = a - 7'd127;
endmodule




module multiplier(prod,  mc, mp, clk);
output [22:0] prod;
input [22:0] mc, mp;
input clk;
reg [24:0] A, Q, M;
reg Q_1;
reg [5:0] count = 0;
wire [24:0] sum, difference;
reg [49:0]prodt;
reg [22:0]prodd;
initial begin
 count = -1;
end

always @(posedge clk)
begin
if(count == 0)
 begin
   A <= 25'b0;
   M <= {1'b0,1'b1,mc};
   Q <= {1'b0,1'b1,mp};
   Q_1 <= 1'b0;

 end
else if(count <=26) 
begin
 case ({Q[0], Q_1})
 2'b00 :  {A, Q, Q_1} <= {{Q[0],A[24:1]}, {A[0],Q[24:1]}, Q[0]};
 2'b01 : {A, Q, Q_1} <= {{Q[0],sum[24:1]}, {sum[0],Q[24:1]}, Q[0]};
 2'b10 : {A, Q, Q_1} <= {{Q[0],difference[24:1]}, {difference[0],Q[24:1]} , Q[0]};
 2'b11 :  {A, Q, Q_1} <= {{Q[0],A[24:1]}, {A[0],Q[24:1]}, Q[0]};
 endcase
   prodt <= {A, Q};
end

else if(count == 27)
 begin
   if((mp[22] == 1'b1) && (mc[22] == 1'b1))
    prodd = prodt[46:24];
  else
    prodd = prodt[45:23];
  count <= -1;
 end
else
  count = count ;
 
count = count + 1;
   

end


alu adder (sum, A, M, 1'b0);
alu subtracter (difference, A, ~M, 1'b1);
/* always@(posedge clk)
begin
  if((mp[22] == 1'b1) && (mc[22] == 1'b1))
    prodd = prodt[46:24];
  else
    prodd = prodt[45:23];
end*/
/*assign prod = prodd;


endmodule


module alu(out, a, b, cin);
output [24:0] out;
input [24:0] a;
input [24:0] b;
input cin;
 assign out = a + b + cin;
endmodule


module ripple_carry_8_bit(a, b, cin,sum, cout);
input [7:0] a,b;
input cin;
output [7:0] sum;
output cout;
wire c1;
 
ripple_carry_4_bit rca1 (
.a(a[3:0]),
.b(b[3:0]),
.cin(cin), 
.sum(sum[3:0]),
.cout(c1));
 
ripple_carry_4_bit rca2(
.a(a[7:4]),
.b(b[7:4]),
.cin(c1),
.sum(sum[7:4]),
.cout(cout));
 
endmodule
 
////////////////////////////////////
//4-bit Ripple Carry Adder
////////////////////////////////////
 
module ripple_carry_4_bit(a, b, cin, sum, cout);
input [3:0] a,b;
input cin;
wire c1,c2,c3;
output [3:0] sum;
output cout;
 
full_adder fa0(.a(a[0]), .b(b[0]),.cin(cin), .sum(sum[0]),.cout(c1));
full_adder fa1(.a(a[1]), .b(b[1]), .cin(c1), .sum(sum[1]),.cout(c2));
full_adder fa2(.a(a[2]), .b(b[2]), .cin(c2), .sum(sum[2]),.cout(c3));
full_adder fa3(.a(a[3]), .b(b[3]), .cin(c3), .sum(sum[3]),.cout(cout));
endmodule
 
//////////////////////////////
//1bit Full Adder
/////////////////////////////
module full_adder(a,b,cin,sum, cout);
input a,b,cin;
output sum, cout;
wire x,y,z;
half_adder h1(.a(a), .b(b), .sum(x), .cout(y));
half_adder h2(.a(x), .b(cin), .sum(sum), .cout(z));
or or_1(cout,z,y);
endmodule
 
///////////////////////////
// 1 bit Half Adder
//////////////////////////
module half_adder( a,b, sum, cout );
input a,b;
output sum, cout;
xor xor_1 (sum,a,b);
and and_1 (cout,a,b);
endmodule*/
