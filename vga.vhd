library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity vga is 
	port ( P1_up , P1_down , P2_up , P2_down  , CLK: in std_logic; --push button inputs 
			VGA_VS , VGA_HS: out std_logic; 
			VGA_OUTPUT : out std_logic_vector(2 downto 0); 
			VGA_BRIG : out std_logic_vector(8 downto 0);
			P1_SEG , P2_SEG : out std_logic_vector(6 downto 0)
			);
end entity;

architecture vga_arc of vga is 
	signal sync_reg : unsigned(23 downto 0) := (others => '0'); --register for the clock signal 
	signal PIX_CLOCK : std_logic := '0';
	signal slow_clk : std_logic := '0';
	
	signal HS , VS  : std_logic;--signals for the buttons and syncs
	signal Hcounter : integer range 0 to 799 := 0;
	signal Vcounter : integer range 0 to 524 := 0;

	--vector that holds the colors for each pixel 
	signal RGB : std_logic_vector(2 downto 0);

	--Variables for the object positions and size 
	-- blocks will take up about (36*160) pixels 
	constant X : integer := 18; 
	constant Y : integer := 80;
	
	signal BLOCK_1_X_POS : integer := 72;--block positions 
	signal BLOCK_1_Y_POS : integer := 240;
	
	signal BLOCK_2_X_POS : integer := 568;
	signal BLOCK_2_Y_POS : integer := 240;
	
	constant R : integer := 18; --radius of the ball 
	
	signal BALL_X_POS: integer := 320; --position of the ball 
	signal BALL_Y_POS : integer := 240;
	
	signal BALL_Vx ,  BALL_Vy : integer := 3; --initial velocities of the ball and blocks 
	signal BLOCK_1_Vy : integer := 3;--velocieties must have initial values
	signal BLOCK_2_Vy : integer := 3;
	
	
	constant Y_BOUNDARY : integer := 480;
	constant X_BOUNDARY : integer := 640;
	
	signal P1_SCORE , P2_SCORE : integer := 0;
	
	constant CENTER_X : integer := 320;
	constant CENTER_Y : integer := 240;
	
	
	begin
	
----------------------------------------------------------------------------------------------------------------------------------
CLOCK_GEN : process(CLK)
	begin
	--the CLK is the 50MHz clock of the FPGA board 
		if rising_edge(CLK) then
			sync_reg <= sync_reg + 1;
			PIX_CLOCK <= sync_reg(0);  --f = 25MHz so we use bit 0
			slow_clk <= sync_reg(19);
		end if;
	end process;
----------------------------------------------------------------------------------------------------------------------------------
--updates the horizotal counter based on the horizontal sync clock
HSYNC : process(PIX_CLOCK)
begin 
    if rising_edge(PIX_CLOCK) then
        if (Hcounter = 799) then
            Hcounter <= 0;
        else
            Hcounter <= Hcounter + 1;
        end if;

        -- HSYNC active-low 656–751
        if (Hcounter >= 656 and Hcounter < 752) then
            HS <= '0';
        else
            HS <= '1';
        end if;
    end if;
end process;

VGA_HS <= HS;

----------------------------------------------------------------------------------------------------------------------------------		
--updates the vertical counter based on the vertical sync clock
VSYNC : process(PIX_CLOCK)
begin
    if rising_edge(PIX_CLOCK) then
        if (Hcounter = 799) then      -- ONLY UPDATE AT END OF EACH LINE
            if (Vcounter = 524) then
                Vcounter <= 0;
            else
                Vcounter <= Vcounter + 1;
            end if;
        end if;

        -- VSYNC active-low 490–491
        if (Vcounter >= 490 and Vcounter < 492) then
            VS <= '0';
        else
            VS <= '1';
        end if;
    end if;
end process;

VGA_VS <= VS;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--displays the block and ball 
DISPLAY_GAME : process(VCounter , Hcounter , BLOCK_1_X_POS  , BLOCK_1_Y_POS , BLOCK_2_X_POS , BLOCK_2_Y_POS , BALL_X_POS ,  BALL_Y_POS )
	begin 
		if((Hcounter < 0 )  OR (Hcounter > 640) OR ((Vcounter < 0 ) OR (Vcounter > 480))) then
			RGB <= "000"; --do not display if out of bounds
			VGA_BRIG <= "000000000";
		elsif(((Hcounter >= BLOCK_1_X_POS - X) AND (Hcounter <= BLOCK_1_X_POS + X)) AND ((Vcounter >= BLOCK_1_Y_POS - Y) AND (Vcounter <= BLOCK_1_Y_POS + Y))) then
			RGB <= "111";
			VGA_BRIG <= "111111111";
		elsif (((Hcounter >= BLOCK_2_X_POS - X) AND (Hcounter <= BLOCK_2_X_POS + X)) AND ((Vcounter >= BLOCK_2_Y_POS - Y) AND (Vcounter <= BLOCK_2_Y_POS + Y))) then
			RGB <= "111";
			VGA_BRIG <= "111111111";
		elsif (((Hcounter - BALL_X_POS)*(Hcounter - BALL_X_POS) + (Vcounter - BALL_Y_POS)*(Vcounter - BALL_Y_POS)) <= (R)*(R)) then 
			RGB <= "111";
			VGA_BRIG <= "111111111";
		else 
			RGB <= "000";
			VGA_BRIG <= "000000000";
		end if;
		
		
		VGA_OUTPUT <= RGB;
	end process;
	
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--updates the positions of the blocks and ball on every pixel clock
--NB: the x postions of the blocks never change 
--pressing both the up and down buttons causes no shifts in the blocks
POSITIONS :  process(slow_clk)
	begin
	if(rising_edge(slow_clk)) then
		--player 1 is moving their block up 
		if(P1_up = '1' AND P1_down =  '0' AND P2_up = '0' AND P2_down =  '0' AND (BLOCK_1_Y_POS < Y_BOUNDARY)) then
			BLOCK_1_Y_POS <= BLOCK_1_Y_POS + BLOCK_1_Vy;
		--player 1 is moving their block down
		elsif (P1_up = '0' AND P1_down =  '1' AND P2_up = '0' AND P2_down =  '0' AND (BLOCK_1_Y_POS > 0)) then
			BLOCK_1_Y_POS <= BLOCK_1_Y_POS - BLOCK_1_Vy;
		--player 2 is moving their block up 
		elsif (P1_up = '0' AND P1_down =  '0' AND P2_up = '1' AND P2_down =  '0' AND (BLOCK_2_Y_POS < Y_BOUNDARY))  then
			BLOCK_2_Y_POS <= BLOCK_2_Y_POS + BLOCK_2_Vy;
		--Player 2 down 
		elsif (P1_up = '0' AND P1_down =  '0' AND P2_up = '0' AND P2_down =  '1' AND (BLOCK_2_Y_POS > 0))  then
			BLOCK_2_Y_POS <= BLOCK_2_Y_POS - BLOCK_2_Vy;
		--player 1 up and player 2 up
		elsif(P1_up = '1' AND P1_down =  '0' AND P2_up = '1' AND P2_down =  '0' AND (BLOCK_1_Y_POS < Y_BOUNDARY) AND (BLOCK_2_Y_POS < Y_BOUNDARY)) then
			BLOCK_1_Y_POS <= BLOCK_1_Y_POS + BLOCK_1_Vy;
			BLOCK_2_Y_POS <= BLOCK_2_Y_POS + BLOCK_2_Vy;
		--player 1 up and player 2 down 
		elsif(P1_up = '1' AND P1_down =  '0' AND P2_up = '0' AND P2_down =  '1' AND (BLOCK_1_Y_POS < Y_BOUNDARY) AND (BLOCK_2_Y_POS > 0)) then
			BLOCK_1_Y_POS <= BLOCK_1_Y_POS + BLOCK_1_Vy;
			BLOCK_2_Y_POS <= BLOCK_2_Y_POS - BLOCK_2_Vy;
		--player 1 down and player 2 up
		elsif(P1_up = '0' AND P1_down =  '1' AND P2_up = '1' AND P2_down =  '0' AND (BLOCK_1_Y_POS > 0) AND (BLOCK_2_Y_POS < Y_BOUNDARY)) then
			BLOCK_1_Y_POS <= BLOCK_1_Y_POS - BLOCK_1_Vy;
			BLOCK_2_Y_POS <= BLOCK_2_Y_POS + BLOCK_2_Vy;
		--player 1 down  and player 2 down 
		elsif(P1_up = '0' AND P1_down =  '1' AND P2_up = '0' AND P2_down =  '1'AND (BLOCK_1_Y_POS > 0) AND (BLOCK_2_Y_POS > 0)) then
			BLOCK_1_Y_POS <= BLOCK_1_Y_POS - BLOCK_1_Vy;
			BLOCK_2_Y_POS <= BLOCK_2_Y_POS - BLOCK_2_Vy;
		else
			BLOCK_1_Y_POS <= BLOCK_1_Y_POS;
			BLOCK_2_Y_POS <= BLOCK_2_Y_POS;		
		end if;
		
		--update the balls velocities 
		--the ball hits block 1 straignt on 
		if((BALL_X_POS - R <= BLOCK_1_X_POS + X) AND (BALL_X_POS + R >= BLOCK_1_X_POS - X)  AND ((BALL_Y_POS + R >= BLOCK_1_Y_POS - Y) AND (BALL_Y_POS - R <= BLOCK_1_Y_POS + Y))) then
            if BALL_Vx < 0 then
                BALL_Vx <= -BALL_Vx;
            else
                -- optional: if ball inside paddle but moving right, push it out
                BALL_Vx <= BALL_Vx;
            end if;
		--  the ball hits block 2 straight on 
		elsif ((BALL_X_POS + R >= BLOCK_2_X_POS - X) AND (BALL_X_POS - R <= BLOCK_2_X_POS + X) AND ((BALL_Y_POS  + R >= BLOCK_2_Y_POS - Y) AND  (BALL_Y_POS - R <= BLOCK_2_Y_POS + Y))) then
           if BALL_Vx > 0 then
                BALL_Vx <= -BALL_Vx;
            else
                BALL_Vx <= BALL_Vx;
            end if;
		end if;
			
			
		--ball hits the top of block 1
		if(((BALL_X_POS - R >= BLOCK_1_X_POS - X) AND (BALL_X_POS + R <= BLOCK_1_X_POS + X)) AND ((BALL_Y_POS + R >= BLOCK_1_Y_POS - Y) AND (BALL_Y_POS - R <= BLOCK_1_Y_POS - Y)) AND (BALL_Vy > 0)) then 
			BALL_Vy <= -BALL_Vy;
			
		--ball hits the bottom of block 1
		elsif(((BALL_X_POS - R >= BLOCK_1_X_POS - X) AND (BALL_X_POS + R <= BLOCK_1_X_POS + X)) AND ((BALL_Y_POS - R <= BLOCK_1_Y_POS + Y) AND (BALL_Y_POS + R >= BLOCK_1_Y_POS + Y)) AND (BALL_Vy < 0)) then 
			BALL_Vy <= -BALL_Vy;
		end if;
		
			
		--ball hits the top of the block 2
		if(((BALL_X_POS - R >= BLOCK_2_X_POS - X) AND  (BALL_X_POS + R <= BLOCK_2_X_POS + X)) AND ((BALL_Y_POS + R >= BLOCK_2_Y_POS - Y) AND  (BALL_Y_POS - R <= BLOCK_2_Y_POS - Y)) AND (BALL_Vy > 0)) then 
			BALL_Vy <= -BALL_Vy;	

		--ball hits the bottom of the block 2
		elsif(((BALL_X_POS - R >= BLOCK_2_X_POS - X) AND  (BALL_X_POS + R <= BLOCK_2_X_POS + X)) AND ((BALL_Y_POS - R <= BLOCK_2_Y_POS + Y) AND (BALL_Y_POS + R >= BLOCK_2_Y_POS + Y)) AND (BALL_Vy < 0)) then 
			BALL_Vy <= -BALL_Vy;	
		end if;

			
		--ball hits the top  boundary 
		if((BALL_Y_POS + R >= Y_BOUNDARY) AND (BALL_Vy > 0)) then 
			BALL_Vy <= -BALL_Vy;	
		--ball hits the bottom boundary 
		elsif((BALL_Y_POS - R <= 0) AND (BALL_Vy < 0)) then 
			BALL_Vy <= -BALL_Vy;	
		end if;
			
			
		--ball hits the left  boundary 
		if((BALL_X_POS - R <= 0) AND (BALL_Vx < 0)) then 
			BALL_Vx <= -BALL_Vx;	
			BALL_Vy <= -BALL_Vy;
			

			P2_SCORE <= P2_SCORE + 1;--a point for P2
			if(P2_score > 9) then
				P2_SCORE <= 0; --reset the scores as seven seg only goes to 9
				P1_SCORE <= 0;
			end if;
		--ball hits the right boundary 
		elsif((BALL_X_POS + R >= X_BOUNDARY) AND (BALL_Vx > 0)) then 
			BALL_Vx <= -BALL_Vx;	
			BALL_Vy <= BALL_Vy;
			

			P1_SCORE <= P1_SCORE + 1;--a point for P1
			if(P1_score > 9) then
				P1_SCORE <= 0;
				P2_SCORE <= 0;
			end if;
		end if;
		
		--updating the balls position
		BALL_X_POS <= BALL_X_POS + BALL_Vx;
		BALL_Y_POS <= BALL_Y_POS + BALL_Vy;
	end if;
	end process;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SCORE_KEEPER : process(P1_SCORE , P2_SCORE)
	begin
			case P1_SCORE is 
        when 0 => P1_SEG <= "1000000"; -- 0
        when 1 => P1_SEG <= "1111001"; -- 1
        when 2 => P1_SEG <= "0100100"; -- 2
        when 3 => P1_SEG <= "0110000"; -- 3
        when 4 => P1_SEG <= "0001101"; -- 4
        when 5 => P1_SEG <= "0010010"; -- 5
        when 6 => P1_SEG <= "0000011"; -- 6
        when 7 => P1_SEG <= "1111000"; -- 7
        when 8 => P1_SEG <= "0000000"; -- 8
        when 9 => P1_SEG <= "0010000"; -- 9
        when others => P1_SEG <= "1111111"; -- blank
    end case;
	 
	 case P2_SCORE is
        when 0 => P2_SEG <= "1000000"; -- 0
        when 1 => P2_SEG <= "1111001"; -- 1
        when 2 => P2_SEG <= "0100100"; -- 2
        when 3 => P2_SEG <= "0110000"; -- 3
        when 4 => P2_SEG <= "0001101"; -- 4
        when 5 => P2_SEG <= "0010010"; -- 5
        when 6 => P2_SEG <= "0000011"; -- 6
        when 7 => P2_SEG <= "1111000"; -- 7
        when 8 => P2_SEG <= "0000000"; -- 8
        when 9 => P2_SEG <= "0010000"; -- 9
        when others => P2_SEG <= "1111111"; -- blank
    end case;

end process;
end architecture;
			