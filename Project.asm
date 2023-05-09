#####################################################################
#
# CSCB58 Winter 2023 Assembly Final Project
# University of Toronto, Scarborough
#
# Student: Casper Sajewski-Lee, 1008493701, leecaspe, casper.sajewskilee@mail.utoronto.ca
#
# Bitmap Display Configuration:
# - Unit width in pixels: 4
# - Unit height in pixels: 4
# - Display width in pixels: 256 
# - Display height in pixels: 256 
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone ALL OF THEM
#
# Which approved features have been implemented for milestone 3?
# (See the assignment handout for the list of additional features)
# 1. Shooting Bullets
# 2. Moving Platforms
# 3. Moving Enemies
# 4. Start Menu
#5.Game Over Screen
#6.Win Condition/Victory Screen
#
# Link to video demonstration for final submission:
#   https://www.youtube.com/watch?v=fThvzyIkPAw
#
# Are you OK with us sharing the video with people outside course staff?
# - yes
#
# Any additional information that the TA needs to know:
# - (write here, if any)
#
#####################################################################
.data
Character_Position:	.word	0 #Address of top left most part of character
Enemy_Position_Array: .word	0:50 #Address of top left most part of all enemies currently in play
Platform_Position_Array: .word	0:50 #Address of top left most element of each platform
BULLET_ARRAY:		.word	0:50 #Array holding the current position of all bullets
Bullet_Direction:		.word	0:50 #Array holding the direction that the bullets are going. -1 means left, 1 means right. Positions are the same as in the above array.
Level_Time:			.word	300 #Time, in sleep frequency, that the level will last. If player survives that long, they win
#Maybe use a time value to change difficulty?
#Maybe also use a global time variable to denote the time the player has to live until?

.eqv BASE_ADDRESS 0x10008000
.eqv	YELLOW 0xffff00
.eqv	WHITE 0xffffff
.eqv	RED 0xff0000
.eqv BLACK 0x000000
.eqv SKIN 0xe8beac
.eqv BLUE 0x0000ff
.eqv GREY 0x808080
	
.text

.globl main
#Infinite main loop which will run our game
#####################################################################################
main:
	#Clear the screen to create space for the menu
	jal CLEAR_ARRAYS
	jal CLEAR_SCREEN
	#Initialize the start menu and wait for player input to decide which option to pick
	jal START_MENU
	#Start the game by making a level
	jal CLEAR_SCREEN
	jal MAKE_LEVEL
	#Infinite loop which runs the game
	j RUN_GAME

#####################################################################################



#Helper functions to and actual method of RUN_GAME
###########################################################################
#s1 will store the time the player has spent on the current level
#s2 will denote whether the player is looking left or right (0 = Left, 1 = Right)
#s3 will denote how many frames since the player has touched a platform after a jump (Used for jumping/gravity)
#s4 will denote whether the player is on their way up or down (-1=down, 1=up)
#s0 will denote the amount of time since the last platform update (useful for moving platforms every third frame)
RUN_GAME:
	la $t0, Level_Time
	lw $t0, 0($t0)
	#s1 stores time, if equal to the time allocated. The player survived and has won
	beq $s1, $t0, GAME_WON
	#Detects and perform functionality on user input
	jal HANDLE_PLAYER
	#Performs all background functionality (gravity, moving platforms, enemies, bullets)
	jal HANDLE_ENVIRONMENT
	#Add to our time register
	addi $s1, $s1, 1
	j RUN_GAME


#Handles all functionality with everything not related to the player	
HANDLE_ENVIRONMENT:
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	li $t0, 2
	beq $s0, $t0, PLATFORM_MOVES
	jal HANDLE_PLAYER_GRAVITY
	jal HANDLE_BULLETS
	li $v0, 32
	li $a0, 50
	syscall
	addi $s0, $s0, 1
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
PLATFORM_MOVES:
	li $s0, 0
	jal HANDLE_PLATFORM_MOVEMENT
	jal HANDLE_PLAYER_GRAVITY
	jal HANDLE_BULLETS
	jal HANDLE_ENEMIES
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#Generate a random enemy, then move all the enemies
HANDLE_ENEMIES:
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	la $t2, Enemy_Position_Array
	subi $sp, $sp, 4
	sw $t2, 0($sp)
	jal FIND_EMPTY_ARRAY
	#t0 will hold the address of where we put the enemy's location
	#We first check if the array is full (the helper function passed -1)
	#in which case we simply move all the current enemies without making more
	li $t1, -1
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	beq $t0, $t1, ARRAY_FULL
	la $t2, Enemy_Position_Array
	add $t0, $t0, $t2
	li $v0, 42
	li $a0, 0
	li $a1, 62
	syscall
	add $t1, $a0, $zero
	li $t2, 256
	mult $t1, $t2
	mflo $t1
	li $t2, BASE_ADDRESS
	add $t1, $t1, $t2
	sw $t1, 0($t0)
	#We store the random location the enemy will appear in at t1
	subi $sp, $sp, 4
	sw $t1, 0($sp)
	jal MAKE_ENEMY
	jal MOVE_ALL_ENEMIES
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#If there is no more space in the above array for enemies, move all current enemies and don't make any more
ARRAY_FULL:
	addi $sp, $sp, 4
	jal MOVE_ALL_ENEMIES
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
#Called by the Handle_Enemies helper function, iterates through the array to move all enemies right,
#If they hit the right side of the screen, delete them
MOVE_ALL_ENEMIES:
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	la $t0, Enemy_Position_Array
	li $t1, 0
	li $t2, 196
	j Enemy_Arr_Loop
	
#While loop that goes through the entire array, moving any enemy it finds
Enemy_Arr_Loop:
	beq $t1, $t2, END_LOOP
	lw $t3, 0($t0)
	bnez $t3, MOVE_ENEMY
	addi $t0, $t0, 4
	addi $t1, $t1, 4
	j Enemy_Arr_Loop

#Moves the enemy with topleft address at t3 and updates their position in the
#array. Preserves t0 as the address of the enemy to move
MOVE_ENEMY:
	subi $sp, $sp, 4
	sw $t3, 0($sp)
	jal CLEAR_ENEMY
	addi $t3, $t3, 4
	li $t4, 256
	div $t3, $t4
	mfhi $t4
	li $t5, 252
	beq $t4, $t5, REMOVE_ENEMY
	subi $sp, $sp, 4
	sw $t3, 0($sp)
	jal MAKE_ENEMY
	sw $t3, 0($t0)
	addi $t0, $t0, 4
	addi $t1, $t1, 4
	j Enemy_Arr_Loop
	
#Clears the enemy at the location passed as an argument	
CLEAR_ENEMY:
	lw $t4, 0($sp)
	addi $sp, $sp, 4
	li $t5, BLACK
	li $t6, -1
	beq $t4, $t6, STOP_CLEAR_ENEMY
	sw $t5, 0($t4)
	sw $t5, 4($t4)
	sw $t5, 256($t4)
	sw $t5, 260($t4)
	jr $ra
	
STOP_CLEAR_ENEMY:
	jr $ra

#Denotes that we need to remove the enemy from the display and the game
#Used in the above while loop to clear an enemy which has hit a player
#or a bullet	
REMOVE_ENEMY:
	sw $zero, 0($t0)
	addi $t0, $t0, 4
	addi $t1, $t1, 4
	j Enemy_Arr_Loop


#Makes an enemy with top left address passed by the caller
#Does not update the array (Expects caller to update the enemy array)
MAKE_ENEMY:
	lw $t3, 0($sp)
	addi $sp, $sp, 4
	li $t5, WHITE
	#Check for collision with player or bullets by looking for the colors of  those things
	li $t6, GREY
	li $t7, YELLOW
	li $t8, BLUE
	lw $t9, -8($t3)
	beq $t6, $t9, REMOVE_ENEMY
	lw $t9, -4($t3)
	beq $t6, $t9, REMOVE_ENEMY
	lw $t9, 0($t3)
	beq $t6, $t9, REMOVE_ENEMY
	lw $t9, 4($t3)
	beq $t6, $t9, REMOVE_ENEMY
	lw $t9, 8($t3)
	beq $t6, $t9, REMOVE_ENEMY
	lw $t9, 252($t3)
	beq $t6, $t9, REMOVE_ENEMY
	lw $t9, 256($t3)
	beq $t6, $t9, REMOVE_ENEMY
	lw $t9, 260($t3)
	beq $t6, $t9, REMOVE_ENEMY
	lw $t9, 264($t3)
	beq $t6, $t9, REMOVE_ENEMY
	beq $t7, $t9, GAME_OVER
	beq $t8, $t9, GAME_OVER
	sw $t5, 0($t3)
	lw $t9, 4($t3)
	beq $t6, $t9, REMOVE_ENEMY
	beq $t7, $t9, GAME_OVER
	beq $t8, $t9, GAME_OVER
	sw $t5, 4($t3)
	lw $t9, 256($t3)
	beq $t6, $t9, REMOVE_ENEMY
	beq $t7, $t9, GAME_OVER
	beq $t8, $t9, GAME_OVER
	sw $t5, 256($t3)
	lw $t9, 260($t3)
	beq $t6, $t9, REMOVE_ENEMY
	beq $t7, $t9, GAME_OVER
	beq $t8, $t9, GAME_OVER
	sw $t5, 260($t3)
	jr $ra
	
	
#Handles moving all platforms up/down depending on column
HANDLE_PLATFORM_MOVEMENT:
	#Initialize all needed values, then branch to a loop to handle the platform performance
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	la $s7, Platform_Position_Array
	addi $t7, $s7, 196
	j HANDLE_PLATFORM_LOOP

#Called by the above called method, loops through the platform array to move them up/down as needed	
HANDLE_PLATFORM_LOOP:
	#Load the address from our array
	lw $t2, 0($s7)
	sw $zero, 0($s7)
	#Load some constants that we can use to divide to decide to move up/down
	li $t3, 256
	div $t2, $t3
	mfhi $t3
	#We have reached the end of our initialized array
	beq $t7, $s7, END_LOOP
	#Check the correct columns to see if we need to move the platform in question up
	li $t4, 16
	beq $t3, $t4, MOVE_PLATFORM_UP
	li $t4, 112
	beq $t3, $t4, MOVE_PLATFORM_UP
	li $t4, 208
	beq $t3, $t4, MOVE_PLATFORM_UP
	li $t4, 64
	beq $t3, $t4, MOVE_PLATFORM_DOWN
	li $t4, 160
	beq $t3, $t4, MOVE_PLATFORM_DOWN
	addi $s7, $s7, 4
	j HANDLE_PLATFORM_LOOP
	
#Called by the above loop to move the platform up
#Keeps the value of t2 and iterates t0 (address of platform and array index to study respectively
#Moving a platform up also comes with the special case that the character is on the platform,
#in which case we must move them up as well
MOVE_PLATFORM_UP:
	subi $sp, $sp, 4
	sw $t2, 0($sp)
	jal CLEAR_PLATFORM
	subi $t2, $t2, 256
	li $t3, BASE_ADDRESS
	blt $t2, $t3, JUMP_TO_BOTTOM_OF_SCREEN
	li $t3, BLUE
	subi $t5, $t2, 4
	lw $t4, 0($t5)
	beq $t3, $t4, MOVE_CHAR_UP
	addi $t5, $t5, 4
	lw $t4, 0($t5)
	beq $t3, $t4, MOVE_CHAR_UP
	addi $t5, $t5, 4
	lw $t4, 0($t5)
	beq $t3, $t4, MOVE_CHAR_UP
	addi $t5, $t5, 4
	lw $t4, 0($t5)
	beq $t3, $t4, MOVE_CHAR_UP
	addi $t5, $t5, 4
	lw $t4, 0($t5)
	beq $t3, $t4, MOVE_CHAR_UP
	addi $t5, $t5, 4
	lw $t4, 0($t5)
	beq $t3, $t4, MOVE_CHAR_UP
	addi $t5, $t5, 4
	lw $t4, 0($t5)
	beq $t3, $t4, MOVE_CHAR_UP
	addi $t5, $t5, 4
	lw $t4, 0($t5)
	beq $t3, $t4, MOVE_CHAR_UP
	addi $t5, $t5, 4
	lw $t4, 0($t5)
	beq $t3, $t4, MOVE_CHAR_UP
	subi $sp, $sp, 4
	sw $t2, 0($sp)
	jal MAKE_PLATFORM
	addi $s7, $s7, 4
	j HANDLE_PLATFORM_LOOP
	
#We've detected the blue of the lower part of the character, so as an additional step, we must make the character at one level up
MOVE_CHAR_UP:
	subi $t4, $t5, 768
	#Maintain local variable by pushing to the stack
	subi $sp, $sp, 4
	sw $t2, 0($sp)
	jal CLEAR_CHARACTER
	li $t4, 0
	beq $t4, $s2, CHAR_UP_LEFT
	j CHAR_UP_RIGHT
	
CHAR_UP_LEFT:
	lw $t2, 0($sp)
	addi $sp, $sp, 4
	subi $t4, $t5, 1024
	subi $sp, $sp, 4
	sw $t2, 0($sp)
	subi $sp, $sp, 4
	sw $t4, 0($sp)
	jal MAKE_CHARACTER_LEFT
	lw $t2, 0($sp)
	addi $sp, $sp, 4
	subi $sp, $sp, 4
	sw $t2, 0($sp)
	jal MAKE_PLATFORM
	addi $s7, $s7, 4
	j HANDLE_PLATFORM_LOOP

CHAR_UP_RIGHT:
	lw $t2, 0($sp)
	addi $sp, $sp, 4
	subi $t4, $t5, 1024
	subi $sp, $sp, 4
	sw $t2, 0($sp)
	subi $sp, $sp, 4
	sw $t4, 0($sp)
	jal MAKE_CHARACTER_RIGHT
	lw $t2, 0($sp)
	addi $sp, $sp, 4
	subi $sp, $sp, 4
	sw $t2, 0($sp)
	jal MAKE_PLATFORM
	addi $s7, $s7, 4
	j HANDLE_PLATFORM_LOOP

JUMP_TO_BOTTOM_OF_SCREEN:
	addi $t2, $t2, 16384
	subi $sp, $sp, 4
	sw $t2, 0($sp)
	jal MAKE_PLATFORM
	addi $s7, $s7, 4
	j HANDLE_PLATFORM_LOOP
	

MOVE_PLATFORM_DOWN:
	subi $sp, $sp, 4
	sw $t2, 0($sp)
	jal CLEAR_PLATFORM
	addi $t2, $t2, 256
	li $t3, BASE_ADDRESS
	addi $t3, $t3, 16384
	bgt $t2, $t3, JUMP_TO_TOP_OF_SCREEN
	subi $sp, $sp, 4
	sw $t2, 0($sp)
	jal MAKE_PLATFORM
	addi $s7, $s7, 4
	j HANDLE_PLATFORM_LOOP
	
JUMP_TO_TOP_OF_SCREEN:
	subi $t2, $t2, 16384
	subi $sp, $sp, 4
	sw $t2, 0($sp)
	jal MAKE_PLATFORM
	addi $s7, $s7, 4
	j HANDLE_PLATFORM_LOOP
	

#Moves bullets in their correct direction according to the Bullet_Direction macro.
HANDLE_BULLETS:
	#Initialize all needed values, then branch to a loop to handle the bullet performance
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	la $t0 BULLET_ARRAY
	la $t1, Bullet_Direction
	addi $t6, $t0, 200
	j BULLET_HANDLE_LOOP

	
#Loop to iterate through the bullet arrays and move them accordingly
BULLET_HANDLE_LOOP:
	lw $t2, 0($t0)
	lw $t3, 0($t1)
	#Load some constants that we can use to compare and branch as needed
	li $t4, -1
	li $t5, 1
	#We have reached the end of our initialized array
	beq $t0, $t6, END_LOOP
	beq $t3, $t4, MOVE_BULLET_LEFT
	beq $t3, $t5, MOVE_BULLET_RIGHT
	addi $t0, $t0, 4
	addi $t1, $t1, 4
	j BULLET_HANDLE_LOOP
	
#Move the bullet allocated in t2 to the left by one pixel, then iterate through the loop and return to loop
MOVE_BULLET_LEFT:
	li $t4, BLACK
	li $t5, GREY
	sw $t4, 0($t2)
	li $t4, 256
	div $t2, $t4
	mfhi $t4
	subi $t2, $t2, 4
	beqz $t4, CLEAR_BULLET
	sw $t5, 0($t2)
	sw $t2, 0($t0)
	addi $t0, $t0, 4
	addi $t1, $t1, 4
	j BULLET_HANDLE_LOOP
	
MOVE_BULLET_RIGHT:
	li $t4, BLACK
	sw $t4, 0($t2)
	li $t4, 256
	div $t2, $t4
	mfhi $t4
	addi $t2, $t2, 4
	li $t5, 252
	beq $t4, $t5 CLEAR_BULLET
	li $t5, GREY
	sw $t5, 0($t2)
	sw $t2, 0($t0)
	addi $t0, $t0, 4
	addi $t1, $t1, 4
	j BULLET_HANDLE_LOOP
	
CLEAR_BULLET:
	sw $zero, 0($t0)
	sw $zero, 0($t1)
	addi $t0, $t0, 4
	addi $t1, $t1, 4
	j BULLET_HANDLE_LOOP

#End the above loop by jumping jumping back to caller
END_LOOP:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
		
#Checks if player is on floor, and makes them fall or rise depending on if they jumped recently
#or are just falling
HANDLE_PLAYER_GRAVITY:
	#Push return address
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	#Load and keep pointer to character position address in t0
	la $t0, Character_Position
	#Load and keep the actual address itself at t1
	lw $t0, 0($t0)
	#Check underneath the character to see if they are standing on a platform
	lw $t2, 1024($t0)
	lw $t3, 1028($t0)
	#Load red hex code to t3 to compare with above addresses to see if we need to apply gravity
	li $t4, RED
	beq $t2, $t4, NO_GRAVITY_APPLIED
	beq $t3, $t4 NO_GRAVITY_APPLIED
	#At this point in our method, we know that our character is not standing on a platform,
	#We need to either move them up for jumping or move them down for falling
	#Check s4 to see if we are jumping or falling
	#in case of walking off an edge, s4 will be 0 and we should update our 
	#s4 accordingly
	#Load 1 into t2. Compare this with s4 to see if we are jumping or falling
	li $t2, 1
	beq $t2, $s4, GRAVITY_UP
	j GRAVITY_DOWN
	

#An oddly named function that is called shortly after a player jumps
#Denotes that we either need to move them up one space, or
#change the direction of the movement from up to down
#Preserves t0 (the address of the character before the jump)
GRAVITY_UP:
	li $t1, 10
	beq $s3, $t1, CHANGE_DIRECTION
	addi $s3, $s3, 1
	jal CLEAR_CHARACTER
	li $t1, 0
	beq $s2, $t1, UP_LEFT
	j UP_RIGHT
	
#Helper function to the above that denotes that we need to move
#the character up and face them left
UP_LEFT:
	subi $t0, $t0, 256
	subi $sp, $sp, 4
	sw $t0, 0($sp)
	jal MAKE_CHARACTER_LEFT
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#Helper function that denotes we need to move the character up
#and face them right
UP_RIGHT:
	subi $t0, $t0, 256
	subi $sp, $sp, 4
	sw $t0, 0($sp)
	jal MAKE_CHARACTER_RIGHT
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#Helper function to GRAVITY_UP. Denotes that we are finished our jump
#and should update our macros to know move us down
CHANGE_DIRECTION:
	#We have reached the end of our jump, so reset the value of s3 to 0
	li $s3, 0
	li $s4, -1
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#Denotes that we need to move the character down a level
#Updates all necessary macros and moves the character down one pixel
#Preserves t0, which is set by the caller to be the address of the character
#before moving them
GRAVITY_DOWN:
	jal CLEAR_CHARACTER
	li $t1, 0
	beq $s2, $t1, FALL_LEFT
	j FALL_RIGHT
	
#Denotes that we want to face the character right and have them fall
FALL_RIGHT:
	addi $t0, $t0, 256
	subi $sp, $sp, 4
	sw $t0, 0($sp)
	jal MAKE_CHARACTER_RIGHT
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

#Denotes that we want to face the character left and have them fall
FALL_LEFT:
	addi $t0, $t0, 256
	subi $sp, $sp, 4
	sw $t0, 0($sp)
	jal MAKE_CHARACTER_LEFT
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#The character is standing on a platform, so no gravity will be applied to them, jump back to caller
NO_GRAVITY_APPLIED:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
	
#Handles all the functionality surrounding the player character
HANDLE_PLAYER:
	li $t0, 1
	li $t1, 0xffff0000
	lw $t2, 0($t1)
	#Branch if the player has pressed a button
	beq $t0, $t2, CHECK_PLAYER_INPUT
	#Our branch will not return, so if we are here we know the player has not pressed a button
	jr $ra

#Checks which button the player has pressed, assumption being that they have pressed a button to begin with
CHECK_PLAYER_INPUT:
	lw $t2, 4($t1)
	#w key
	li $t3, 119
	#a key
	li $t4, 97
	#d key
	li $t5, 100
	#m key
	li $t6, 109
	#p key
	li $t7, 112
	#Branch to the correct statement depending on the key pressed, ignoring unneeded keys
	beq $t2, $t3, JUMP
	beq $t2, $t4, LEFT
	beq $t2, $t5, RIGHT
	beq $t2, $t6, SHOOT
	beq $t2, $t7, QUIT_GAME
	#At this point, we know nothing important has been pressed. Return to the loop
	jr $ra
	
#Helper functions and main function for jump
################################################################################################
#Handle the case where player presses w
JUMP:
	#Push return address
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	#We first need to check that the character is on the platform (no midair jumps)
	la $t0, Character_Position
	lw $t0, 0($t0)
	#Check the floor below the character
	lw $t1, 1024($t0)
	lw $t2, 1028($t0)
	li $t3, RED
	#Branch to ignore the input if not on platform
	beq $t1, $t3, ON_PLATFORM
	beq $t2, $t3, ON_PLATFORM
	#We have not branched to any statement, so we know we don't need to do the jump and can exit
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
	
#Handle the case that we are jumping and facing right
JUMP_RIGHT:
	la $t0, Character_Position
	lw $t0, 0($t0)
	#Clear the character at current position
	jal CLEAR_CHARACTER
	la $t0, Character_Position
	lw $t0, 0($t0)
	#Make the character at one level up from previous position
	subi $t0, $t0, 256
	subi $sp, $sp, 4
	sw $t0, 0($sp)
	jal MAKE_CHARACTER_RIGHT
	#Go back to the caller
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#Handle the case we are jumping and facing left
JUMP_LEFT:
	la $t0, Character_Position
	lw $t0, 0($t0)
	#Clear the character at current position
	jal CLEAR_CHARACTER
	la $t0, Character_Position
	lw $t0, 0($t0)
	#Make the character at one level up from previous position
	subi $t0, $t0, 256
	subi $sp, $sp, 4
	sw $t0, 0($sp)
	jal MAKE_CHARACTER_LEFT
	#Go back to the caller
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
	
ON_PLATFORM:
	#We know now that we need to do the jump
	#Update our macros s3 and s4 to denote that 
	#it has been 1 frame since the player touched a platform
	# and the player should be rising, respectively
	li $s3, 1
	li $s4, 1
	#Load 0 to check with s2 to check what direction we are looking in
	li $t0, 0
	#Detect whether our character is looking left or right, to make them face appriopriately during the jump
	beq $s2, $t0, JUMP_LEFT
	j JUMP_RIGHT
################################################################################################
#End of jump







#Perform functionality after the user presses a
LEFT:
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	li $t0, 0
	beq $s2, $t0, MOVE_LEFT
	#At this point, we know we only need to rotate our character right, and set s appropriately
	la $t1, Character_Position
	lw $t1, 0($t1)
	subi $sp, $sp, 4
	sw $t1, 0($sp)
	jal MAKE_CHARACTER_LEFT
	#Return back to main RUN_GAME loop
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
#Checks collision with platform to the left. 
#Moves the character one position to the left if no collision
MOVE_LEFT:
	#Check whether we would bump into a platform, which means we have to stop the move
	la $t1, Character_Position
	lw $t1, 0($t1)
	li $t2, RED
	lw $t3, -4($t1)
	beq $t3, $t2, NO_MOVE
	lw $t3, 252($t1)
	beq $t3, $t2, NO_MOVE
	lw $t3, 508($t1)
	beq $t3, $t2, NO_MOVE
	lw $t3, 764($t1)
	beq $t3, $t2, NO_MOVE
	#Erase the character from the game, will reprint at next location
	jal CLEAR_CHARACTER
	#We want to move the character left, so make the character at -4 pixels from last area
	la $t1, Character_Position
	lw $t1, 0($t1)
	subi $t1, $t1, 4
	subi $sp, $sp, 4
	sw $t1, 0($sp)
	jal MAKE_CHARACTER_LEFT
	#Return back to main RUN_GAME loop
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
	
#Move right. Functionality for user pressing d
RIGHT:
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	li $t0, 1
	beq $s2, $t0, MOVE_RIGHT
	#At this point, we know we only need to rotate our character left, and set s2 appropriately
	la $t1, Character_Position
	lw $t1, 0($t1)
	subi $sp, $sp, 4
	sw $t1, 0($sp)
	jal MAKE_CHARACTER_RIGHT
	#Return back to main RUN_GAME loop
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#Move the character one position to the right
MOVE_RIGHT:
	la $t1, Character_Position
	lw $t1, 0($t1)
	li $t2, RED
	lw $t3, 8($t1)
	beq $t3, $t2, NO_MOVE
	lw $t3, 264($t1)
	beq $t3, $t2, NO_MOVE
	lw $t3, 520($t1)
	beq $t3, $t2, NO_MOVE
	lw $t3, 776($t1)
	beq $t3, $t2, NO_MOVE
	#Erase the character from the game, will reprint at next location
	jal CLEAR_CHARACTER
	#We want to move the character right, so make the character at 4 pixels from last area
	la $t1, Character_Position
	lw $t1, 0($t1)
	addi $t1, $t1, 4
	subi $sp, $sp, 4
	sw $t1, 0($sp)
	jal MAKE_CHARACTER_RIGHT
	#Return back to main RUN_GAME loop
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
NO_MOVE:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra	
	
	
#Perform the required functionality when the player presses m (Shooting the gun)
SHOOT:
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	#s2 holds the direction our player is facing, so shoot the gun in the appropriate direction
	#Check whether the player is looking left, in which case shoot left
	li $t0, 0
	beq $t0, $s2, SHOOT_LEFT
	j SHOOT_RIGHT
	
#Shoots a bullet to the left of the character. Only called when the player actually fires the gun
SHOOT_LEFT:
	la $t0, Character_Position
	lw $t0, 0($t0)
	#Color of the bullet
	li $t1, GREY
	#We need the bullet to appear one down and to the left of the main character's top left head.
	addi $t0, $t0, 252
	sw $t1, 0($t0)
	#We need to save the bullet address into our array for later use
	#Load args to Bullet_Pos method then call the method
	subi $sp, $sp, 4
	sw $t0, 0($sp)
	subi $sp, $sp, 4
	li $t0, -1
	sw $t0, 0($sp)
	jal UPDATE_BULLET_POS
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#Shoots a bullet to the right of the character. Only called when the player actually fires the gun
SHOOT_RIGHT:
	la $t0, Character_Position
	lw $t0, 0($t0)
	#Color of the bullet
	li $t1, GREY
	#We need the bullet to appear one down and to the left of the main character's top left head.
	addi $t0, $t0, 264
	sw $t1, 0($t0)
	#We need to save the bullet address into our array for later use
	#Load args to Bullet_Pos method then call the method
	subi $sp, $sp, 4
	sw $t0, 0($sp)
	subi $sp, $sp, 4
	li $t0, 1
	sw $t0, 0($sp)
	jal UPDATE_BULLET_POS
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	

	
#Helper function to the environment and to the shooting methods. 
#Accepts 2 arguments, the first pushed is the address of the place to put the bullet
#Second argument pushed is the direction that bullet will travel (-1 for left, 1 for right) 
UPDATE_BULLET_POS:
	#Load the return address
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	la $t0, BULLET_ARRAY
	#Load the arguments then call the method to find where to put our entry
	subi $sp, $sp, 4
	sw $t0, 0($sp)
	jal FIND_EMPTY_ARRAY
	#Load the argument values
	#t0 holds the offset of where to put our next element in bullet array, t1 holds the address of the bullet, 
	#t2 holds the direction. (0=Left, 1=Right)
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	li $t1, -1
	#Check to see if we can not make another bullet, in which case the player is forbidden from shooting
	beq $t0, $t1, NO_MORE_SPACE
	lw $t1, 4($sp)
	lw $t2, 8($sp)
	#Load our macros to update them as needed
	la $t3, BULLET_ARRAY
	la $t4, Bullet_Direction
	#Add offset
	add $t3, $t3, $t0
	add $t4, $t4, $t0
	#Update our macros
	sw $t1, 0($t4)
	sw $t2, 0($t3)
	#Maintain data integrity and get the return address
	lw $ra, 0($sp)
	addi $sp, $sp, 12
	jr $ra
	
	
#Helper function to any update part of our game. Returns to caller since no more of the specified thing can be added to the array
#Operates under the assumption that there are 2 additional elements on the stack (which need to be popped)
NO_MORE_SPACE:
	addi $sp, $sp, 4
	sw $ra, 0($sp)
	addi $sp, $sp, 12
	jr $ra
	
#Helper functions and function for FIND_EMPTY_ARRAY
############################
#Get the next available area in our array to store values into.
#Accepts the first array entry address as an argument
FIND_EMPTY_ARRAY:
	#Pop the required registers off the stack and ready our loop
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	li $t1, 0
	j OFFSET_LOOP
	
#Iterates through the elements of the array address until a 0 (indicating no entry) is found
OFFSET_LOOP:
	#Load the element at the array index to check if it is 0
	lw $t2, 0($t0)
	#Final element of the array, load this value to later check if we have no more space
	li $t3, 196 
	beqz $t2, RETURN_FROM_FIND_ARRAY
	beq $t1, $t3, NO_MORE_SPACE_RETURN
	addi $t0, $t0, 4
	addi $t1, $t1, 4
	j OFFSET_LOOP
	
#Return to caller and push the offset found
RETURN_FROM_FIND_ARRAY:
	subi $sp, $sp, 4
	sw $t1, 0($sp)
	jr $ra
	
NO_MORE_SPACE_RETURN:
	#Return -1 in case no more space
	li $t0, -1
	subi $sp, $sp, 4
	sw $t0, 0($sp)
	jr $ra
	
	
###############################
#End of FIND_EMPTY_ARRAY method



#End game functionality
#####################################################################
#Quits the game and heads back to the menu
QUIT_GAME:
	j main

GAME_OVER:
	jal CLEAR_SCREEN
	li $t0, BASE_ADDRESS
	li $t1, WHITE
	li $t2, RED
	li $t3, BLACK
	sw $t1, 3872($t0)
	sw $t1, 3876($t0)
	sw $t1, 4124($t0)
	sw $t1, 4136($t0)
	sw $t1, 4376($t0)
	sw $t1, 4632($t0)
	sw $t1, 4888($t0)
	sw $t1, 4900($t0)
	sw $t1, 4904($t0)
	sw $t1, 5148($t0)
	sw $t1, 5160($t0)
	sw $t1, 5408($t0)
	sw $t1, 5412($t0)
	
	#Letter A
	sw $t1, 5428($t0)
	sw $t1, 5176($t0)
	sw $t1, 4924($t0)
	sw $t1, 4928($t0)
	sw $t1, 4932($t0)
	sw $t1, 4936($t0)
	sw $t1, 4940($t0)
	sw $t1, 4944($t0)
	sw $t1, 4672($t0)
	sw $t1, 4420($t0)
	sw $t1, 4168($t0)
	sw $t1, 4428($t0)
	sw $t1, 4688($t0)
	sw $t1, 4948($t0)
	sw $t1, 5208($t0)
	sw $t1, 5468($t0)
	
	#Make the letter M
	sw $t1, 5480($t0)
	sw $t1, 5224($t0)
	sw $t1, 4968($t0)
	sw $t1, 4712($t0)
	sw $t1, 4456($t0)
	sw $t1, 4460($t0)
	sw $t1, 4720($t0)
	sw $t1, 4980($t0)
	sw $t1, 5240($t0)
	sw $t1, 5500($t0)
	sw $t1, 5248($t0)
	sw $t1, 4996($t0)
	sw $t1, 4744($t0)
	sw $t1, 4496($t0)
	sw $t1, 4492($t0)
	sw $t1, 4752($t0)
	sw $t1, 5008($t0)
	sw $t1, 5264($t0)
	sw $t1, 5520($t0)
	
	#Make the letter E
	sw $t1, 5540($t0)
	sw $t1, 5544($t0)
	sw $t1, 5548($t0)
	sw $t1, 5552($t0)
	sw $t1, 5284($t0)
	sw $t1, 5028($t0)
	sw $t1, 5032($t0)
	sw $t1, 5036($t0)
	sw $t1, 5040($t0)
	sw $t1, 4772($t0)
	sw $t1, 4516($t0)
	sw $t1, 4520($t0)
	sw $t1, 4524($t0)
	sw $t1, 4528($t0)
	sw $t1, 5520($t0)
	
	#Make the letter O
	sw $t1, 7204($t0)
	sw $t1, 7208($t0)
	sw $t1, 7456($t0)
	sw $t1, 7468($t0)
	sw $t1, 7708($t0)
	sw $t1, 7728($t0)
	sw $t1, 7964($t0)
	sw $t1, 5408($t0)
	sw $t1, 7984($t0)
	sw $t1, 8224($t0)
	sw $t1, 8484($t0)
	sw $t1, 8236($t0)
	sw $t1, 8488($t0)
	sw $t1, 5488($t0)
	
	#Make the letter V
	sw $t1, 7224($t0)
	sw $t1, 7484($t0)
	sw $t1, 7744($t0)
	sw $t1, 8004($t0)
	sw $t1, 8264($t0)
	sw $t1, 8524($t0)
	sw $t1, 8272($t0)
	sw $t1, 8020($t0)
	sw $t1, 7768($t0)
	sw $t1, 7516($t0)
	sw $t1, 7264($t0)
	
	#Make E again
	sw $t1, 7280($t0)
	sw $t1, 7284($t0)
	sw $t1, 7288($t0)
	sw $t1, 7536($t0)
	sw $t1, 7792($t0)
	sw $t1, 7796($t0)
	sw $t1, 7800($t0)
	sw $t1, 8048($t0)
	sw $t1, 8304($t0)
	sw $t1, 8308($t0)
	sw $t1, 8312($t0)
	#Make the letter R
	sw $t1, 7296($t0)
	sw $t1, 7300($t0)
	sw $t1, 7304($t0)
	sw $t1, 7564($t0)
	sw $t1, 7820($t0)
	sw $t1, 8072($t0)
	sw $t1, 8320($t0)
	sw $t1, 8064($t0)
	sw $t1, 7808($t0)
	sw $t1, 8068($t0)
	sw $t1, 7552($t0)
	sw $t1, 8332($t0)
	sw $t1, 8592($t0)
	sw $t1, 8576($t0)
	#Blood animation
	sw $t2, 8560($t0)
	sw $t2, 8564($t0)
	sw $t2, 8568($t0)
	li $v0, 32
	li $a0, 50
	syscall
	sw $t2, 8820($t0)
	syscall
	sw $t2, 9076($t0)
	syscall
	sw $t3, 9076($t0)
	sw $t2, 9332($t0)
	syscall
	sw $t3, 9332($t0)
	sw $t2, 9588($t0)
	syscall
	sw $t3, 9588($t0)
	sw $t2, 9844($t0)
	syscall
	sw $t3, 9844($t0)
	sw $t2, 10100($t0)
	syscall
	sw $t3, 10100($t0)
	sw $t2, 10356($t0)
	syscall
	sw $t3, 10356($t0)
	sw $t2, 10612($t0)
	syscall
	sw $t3, 10612($t0)
	sw $t2, 10868($t0)
	syscall
	sw $t3, 10868($t0)
	sw $t2, 11124($t0)
	syscall
	sw $t3, 11124($t0)
	sw $t2, 11380($t0)
	syscall
	sw $t3, 11380($t0)
	sw $t2, 11636($t0)
	syscall
	sw $t3, 11636($t0)
	sw $t2, 11892($t0)
	syscall
	sw $t3, 11892($t0)
	sw $t2, 12148($t0)
	syscall
	sw $t3, 12148($t0)
	sw $t2, 12404($t0)
	syscall
	sw $t3, 12404($t0)
	sw $t2, 12660($t0)
	syscall
	sw $t3, 12660($t0)
	sw $t2, 12916($t0)
	syscall
	sw $t3, 12916($t0)
	sw $t2, 13172($t0)
	syscall
	sw $t3, 13172($t0)
	sw $t2, 13428($t0)
	syscall
	sw $t3, 13428($t0)
	sw $t2, 13684($t0)
	syscall
	sw $t3, 13684($t0)
	sw $t2, 13940($t0)
	syscall
	sw $t3, 13940($t0)
	sw $t2, 14196($t0)
	syscall
	sw $t3, 14196($t0)
	sw $t2, 14452($t0)
	syscall
	sw $t3, 14452($t0)
	sw $t2, 14708($t0)
	syscall
	sw $t3, 14708($t0)
	sw $t2, 14964($t0)
	syscall
	sw $t3, 14964($t0)
	sw $t2, 15220($t0)
	syscall
	sw $t3, 15220($t0)
	sw $t2, 15476($t0)
	syscall
	sw $t3, 15476($t0)
	sw $t2, 15732($t0)
	syscall
	sw $t3, 15732($t0)
	sw $t2, 15988($t0)
	syscall
	sw $t3, 15988($t0)
	sw $t2, 16244($t0)
	syscall
	sw $t3, 16244($t0)
	li $v0, 10
	syscall
GAME_WON:
	jal CLEAR_SCREEN
	li $t0, BASE_ADDRESS
	li $t2, 50
	j WHITE_VICTORY_TEXT
WHITE_VICTORY_TEXT:
	beq $t2, $zero, END_VICTORY_TEXT
	li $t1, WHITE
	#Make the letter Y
	sw $t1, 3872($t0)
	sw $t1, 4132($t0)
	sw $t1, 4392($t0)
	sw $t1, 4648($t0)
	sw $t1, 4904($t0)
	sw $t1, 5160($t0)
	sw $t1, 5416($t0)
	sw $t1, 4140($t0)
	sw $t1, 3888($t0)
	#Make the letter O
	sw $t1, 3920($t0)
	sw $t1, 4172($t0)
	sw $t1, 4424($t0)
	sw $t1, 4676($t0)
	sw $t1, 4932($t0)
	sw $t1, 5192($t0)
	sw $t1, 5452($t0)
	sw $t1, 5712($t0)
	sw $t1, 5716($t0)
	sw $t1, 5720($t0)
	sw $t1, 5468($t0)
	sw $t1, 5216($t0)
	sw $t1, 4964($t0)
	sw $t1, 4708($t0)
	sw $t1, 4448($t0)
	sw $t1, 4188($t0)
	sw $t1, 3924($t0)
	sw $t1, 3928($t0)
	#Make the letter U
	sw $t1, 3960($t0)
	sw $t1, 4216($t0)
	sw $t1, 4472($t0)
	sw $t1, 4728($t0)
	sw $t1, 4984($t0)
	sw $t1, 5240($t0)
	sw $t1, 5500($t0)
	sw $t1, 5760($t0)
	sw $t1, 5764($t0)
	sw $t1, 5768($t0)
	sw $t1, 5516($t0)
	sw $t1, 5264($t0)
	sw $t1, 5008($t0)
	sw $t1, 4752($t0)
	sw $t1, 4496($t0)
	sw $t1, 4240($t0)
	sw $t1, 3984($t0)
	
	
	#Make the letter W
	sw $t1, 8272($t0)
	sw $t1, 8528($t0)
	sw $t1, 8784($t0)
	sw $t1, 9040($t0)
	sw $t1, 9296($t0)
	sw $t1, 9552($t0)
	sw $t1, 9808($t0)
	sw $t1, 10064($t0)
	sw $t1, 10068($t0)
	sw $t1, 9816($t0)
	sw $t1, 9564($t0)
	sw $t1, 9824($t0)
	sw $t1, 10084($t0)
	sw $t1, 10088($t0)
	sw $t1, 9832($t0)
	sw $t1, 9576($t0)
	sw $t1, 9320($t0)
	sw $t1, 9064($t0)
	sw $t1, 8808($t0)
	sw $t1, 8552($t0)
	sw $t1, 8296($t0)
	#Make the letter I
	sw $t1, 8320($t0)
	sw $t1, 8324($t0)
	sw $t1, 8328($t0)
	sw $t1, 8332($t0)
	sw $t1, 8336($t0)
	sw $t1, 8584($t0)
	sw $t1, 8840($t0)
	sw $t1, 9096($t0)
	sw $t1, 9352($t0)
	sw $t1, 9608($t0)
	sw $t1, 9864($t0)
	sw $t1, 10120($t0)
	sw $t1, 10124($t0)
	sw $t1, 10128($t0)
	sw $t1, 10116($t0)
	sw $t1, 10112($t0)
	#Make the letter N
	sw $t1, 10148($t0)
	sw $t1, 9892($t0)
	sw $t1, 9636($t0)
	sw $t1, 9380($t0)
	sw $t1, 9124($t0)
	sw $t1, 8868($t0)
	sw $t1, 8612($t0)
	sw $t1, 9892($t0)
	sw $t1, 8356($t0)
	sw $t1, 8616($t0)
	sw $t1, 8876($t0)
	sw $t1, 9136($t0)
	sw $t1, 9396($t0)
	sw $t1, 9656($t0)
	sw $t1, 9916($t0)
	sw $t1, 9660($t0)
	sw $t1, 9404($t0)
	sw $t1, 9148($t0)
	sw $t1, 8892($t0)
	sw $t1, 8636($t0)
	sw $t1, 8380($t0)
	sw $t1, 10172($t0)
	#! symbol
	sw $t1, 8400($t0)
	sw $t1, 8656($t0)
	sw $t1, 8912($t0)
	sw $t1, 9168($t0)
	sw $t1, 9424($t0)
	sw $t1, 9680($t0)
	sw $t1, 9936($t0)
	sw $t1, 10448($t0)
	li $t1, YELLOW
	li $v0, 32
	li $a0, 100
	syscall
	subi $t2, $t2, 1
	j MAKE_VICTORY_YELLOW
	
MAKE_VICTORY_YELLOW:
	beq $t2, $zero, END_VICTORY_TEXT
	#Make the letter Y
	sw $t1, 3872($t0)
	sw $t1, 4132($t0)
	sw $t1, 4392($t0)
	sw $t1, 4648($t0)
	sw $t1, 4904($t0)
	sw $t1, 5160($t0)
	sw $t1, 5416($t0)
	sw $t1, 4140($t0)
	sw $t1, 3888($t0)
	#Make the letter O
	sw $t1, 3920($t0)
	sw $t1, 4172($t0)
	sw $t1, 4424($t0)
	sw $t1, 4676($t0)
	sw $t1, 4932($t0)
	sw $t1, 5192($t0)
	sw $t1, 5452($t0)
	sw $t1, 5712($t0)
	sw $t1, 5716($t0)
	sw $t1, 5720($t0)
	sw $t1, 5468($t0)
	sw $t1, 5216($t0)
	sw $t1, 4964($t0)
	sw $t1, 4708($t0)
	sw $t1, 4448($t0)
	sw $t1, 4188($t0)
	sw $t1, 3924($t0)
	sw $t1, 3928($t0)
	#Make the letter U
	sw $t1, 3960($t0)
	sw $t1, 4216($t0)
	sw $t1, 4472($t0)
	sw $t1, 4728($t0)
	sw $t1, 4984($t0)
	sw $t1, 5240($t0)
	sw $t1, 5500($t0)
	sw $t1, 5760($t0)
	sw $t1, 5764($t0)
	sw $t1, 5768($t0)
	sw $t1, 5516($t0)
	sw $t1, 5264($t0)
	sw $t1, 5008($t0)
	sw $t1, 4752($t0)
	sw $t1, 4496($t0)
	sw $t1, 4240($t0)
	sw $t1, 3984($t0)
	
	
	#Make the letter W
	sw $t1, 8272($t0)
	sw $t1, 8528($t0)
	sw $t1, 8784($t0)
	sw $t1, 9040($t0)
	sw $t1, 9296($t0)
	sw $t1, 9552($t0)
	sw $t1, 9808($t0)
	sw $t1, 10064($t0)
	sw $t1, 10068($t0)
	sw $t1, 9816($t0)
	sw $t1, 9564($t0)
	sw $t1, 9824($t0)
	sw $t1, 10084($t0)
	sw $t1, 10088($t0)
	sw $t1, 9832($t0)
	sw $t1, 9576($t0)
	sw $t1, 9320($t0)
	sw $t1, 9064($t0)
	sw $t1, 8808($t0)
	sw $t1, 8552($t0)
	sw $t1, 8296($t0)
	#Make the letter I
	sw $t1, 8320($t0)
	sw $t1, 8324($t0)
	sw $t1, 8328($t0)
	sw $t1, 8332($t0)
	sw $t1, 8336($t0)
	sw $t1, 8584($t0)
	sw $t1, 8840($t0)
	sw $t1, 9096($t0)
	sw $t1, 9352($t0)
	sw $t1, 9608($t0)
	sw $t1, 9864($t0)
	sw $t1, 10120($t0)
	sw $t1, 10124($t0)
	sw $t1, 10128($t0)
	sw $t1, 10116($t0)
	sw $t1, 10112($t0)
	#Make the letter N
	sw $t1, 10148($t0)
	sw $t1, 9892($t0)
	sw $t1, 9636($t0)
	sw $t1, 9380($t0)
	sw $t1, 9124($t0)
	sw $t1, 8868($t0)
	sw $t1, 8612($t0)
	sw $t1, 9892($t0)
	sw $t1, 8356($t0)
	sw $t1, 8616($t0)
	sw $t1, 8876($t0)
	sw $t1, 9136($t0)
	sw $t1, 9396($t0)
	sw $t1, 9656($t0)
	sw $t1, 9916($t0)
	sw $t1, 9660($t0)
	sw $t1, 9404($t0)
	sw $t1, 9148($t0)
	sw $t1, 8892($t0)
	sw $t1, 8636($t0)
	sw $t1, 8380($t0)
	sw $t1, 10172($t0)
	#! symbol
	sw $t1, 8400($t0)
	sw $t1, 8656($t0)
	sw $t1, 8912($t0)
	sw $t1, 9168($t0)
	sw $t1, 9424($t0)
	sw $t1, 9680($t0)
	sw $t1, 9936($t0)
	sw $t1, 10448($t0)
	subi $t2, $t2, 1
	li $t1, WHITE
	li $v0, 32
	li $a0, 100
	syscall
	j WHITE_VICTORY_TEXT
	
END_VICTORY_TEXT:
	li $v0, 10
	syscall


#####################################################################

#Called by main to make everything required for the level, like platforms and character
MAKE_LEVEL:
	li $t8, 0
	#Push return address register to stack pointer
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	#Make the platforms
	jal MAKE_ALL_PLATFORMS
	subi $sp, $sp, 4
	li $t0, BASE_ADDRESS
	addi $t0, $t0, 3968
	sw $t0, 0($sp)
	#Make the character (initially looks right)
	jal MAKE_CHARACTER_RIGHT
	#s0 will be 1 since the player starts alive
	li $s0, 1
	#s1 will store the time that the player has been playing, in frequency ticks. Starts at 0.
	li $s1, 0
	lw $ra, 0($sp),
	addi $sp, $sp, 4
	jr $ra

#Accepts a memory address as input to the top-left most address of the character, builds the character using that address as reference facing right
MAKE_CHARACTER_RIGHT:
	#Pop the address to make our character from the stack
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	li $t1, BASE_ADDRESS
	addi $t1, $t1, 16384
	#Move the character to the top of the screen in case they fall off the bottom of the screen
	bgt $t0, $t1, CHAR_TOP_SCREEN_RIGHT
	#Update our macro
	la $t1, Character_Position
	sw $t0, 0($t1)
	#Update s2, which denotes the current direction the character is facing
	li $s2, 1
	#Load macros for colors
	li $t1, SKIN
	li $t2, YELLOW
	li $t3, BLUE
	#Make facing right character
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 256($t0)
	sw $t1, 260($t0)
	sw $t3, 512($t0)
	sw $t3, 516($t0)
	sw $t3, 768($t0)
	sw $t3, 772($t0)
	jr $ra

#Make character facing left
MAKE_CHARACTER_LEFT:
	#Pop the address to make our character from the stack
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	li $t1, BASE_ADDRESS
	addi $t1, $t1, 16384
	#Move the character to the top of the screen in case they fall off the bottom of the screen
	bgt $t0, $t1, CHAR_TOP_SCREEN_LEFT
	#Update our macro
	la $t1, Character_Position
	sw $t0, 0($t1)
	#Update s2, the register which stores the direction our character is facing
	li $s2, 0
	#Load color macros
	li $t1, SKIN
	li $t2, YELLOW
	li $t3, BLUE
	#Make character
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t1, 256($t0)
	sw $t2, 260($t0)
	sw $t3, 512($t0)
	sw $t3, 516($t0)
	sw $t3, 768($t0)
	sw $t3, 772($t0)
	jr $ra
	
CHAR_TOP_SCREEN_LEFT:
	subi $t0, $t0, 16384
	#Update our macro
	la $t1, Character_Position
	sw $t0, 0($t1)
	#Update s2, the register which stores the direction our character is facing
	li $s2, 0
	#Load color macros
	li $t1, SKIN
	li $t2, YELLOW
	li $t3, BLUE
	#Make character
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t1, 256($t0)
	sw $t2, 260($t0)
	sw $t3, 512($t0)
	sw $t3, 516($t0)
	sw $t3, 768($t0)
	sw $t3, 772($t0)
	jr $ra
	
CHAR_TOP_SCREEN_RIGHT:
	subi $t0, $t0, 16384
	#Update our macro
	la $t1, Character_Position
	sw $t0, 0($t1)
	#Update s2, which denotes the current direction the character is facing
	li $s2, 1
	#Load macros for colors
	li $t1, SKIN
	li $t2, YELLOW
	li $t3, BLUE
	#Make facing right character
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t2, 256($t0)
	sw $t1, 260($t0)
	sw $t3, 512($t0)
	sw $t3, 516($t0)
	sw $t3, 768($t0)
	sw $t3, 772($t0)
	jr $ra
	
#Clears the character from the screen (usually in order to move them up/down/left/right)
CLEAR_CHARACTER:
	#Load up all needed constants
	la $t0, Character_Position
	lw $t0, 0($t0)
	li $t1, BLACK
	#Store the color black in all required memory addresses
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 256($t0)
	sw $t1, 260($t0)
	sw $t1, 512($t0)
	sw $t1, 516($t0)
	sw $t1, 768($t0)
	sw $t1, 772($t0)
	#Jump to caller
	jr $ra

#Make platform method and helper functions
#########################################################################################
MAKE_ALL_PLATFORMS:
	#Push return address register to stack pointer
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	li $t0, BASE_ADDRESS
	addi $t0, $t0, 16
	j MAKE_PLATFORMS_LOOP

#Calls a while loop that iterates through the screen to create all the platforms
MAKE_PLATFORMS_LOOP:
#Load the check values (t1 used to check if we move on to the next row, t2 checks if we have gone past the buffer for the screen)
	#Load arguments, then call the MAKE_PLATFORM function
	subi $sp, $sp, 4
	sw $t0, 0($sp)
	jal MAKE_PLATFORM
	#Iterate to the next area to make the next platform
	addi $t0, $t0, 48
	li $t1, 256
	#Compare element to t2, which is the greatest index, so if greater, we are done making platforms
	li $t2, BASE_ADDRESS
	addi $t2, $t2, 16384
	#Use the remainder to determine when we have reached the end of the screen and should move to the next row
	#Remainder of 0 means that we are done making platforms for this row
	div $t0, $t1
	mfhi $t1
	#Check if t0 greater than display address
	bge $t0, $t2, END_MAKE_LOOP
	#Check remainder to see if we need to move to next row (If remainder = 0)
	beqz $t1, GO_TO_NEXT_ROW
	#Restart the loop
	j MAKE_PLATFORMS_LOOP
	
#Add the address by some constant to get to the next row
GO_TO_NEXT_ROW:
	addi $t0, $t0, 4624
	j MAKE_PLATFORMS_LOOP
	
#Jump back to caller
END_MAKE_LOOP:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	


#Makes one platform in our game. Recieves an address which is the topleft most pixel of the platform	
MAKE_PLATFORM:
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	#Get the address of the platform array and find the offset to first empty element.
	la $t1, Platform_Position_Array
	subi $sp, $sp, 4
	sw $t1, 0($sp)
	jal FIND_EMPTY_ARRAY
	la $t1, Platform_Position_Array
	lw $t2, 0($sp)
	addi $sp, $sp, 4
	add $t1, $t2, $t1
	#Get the argument, which is the address for the topleft most element of the platform
	lw $t0, 4($sp)
	#Load the argument as the topleft most element of the platform into the array at the correct entry
	sw $t0, 0($t1)
	#Make the platform
	li $t1, RED
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	sw $t1 24($t0)
	sw $t1 28($t0)
	sw $t1, 256($t0)
	sw $t1, 260($t0)
	sw $t1, 264($t0)
	sw $t1, 268($t0)
	sw $t1, 272($t0)
	sw $t1, 276($t0)
	sw $t1, 280($t0)
	sw $t1, 284($t0)
	lw $ra, 0($sp)
	addi $sp, $sp, 8
	jr $ra
	
#Clears the platform at the address passed by caller
CLEAR_PLATFORM:
	#Load the caller
	lw $t3, 0($sp)
	addi $sp, $sp, 4
	li $t4, BLACK
	sw $t4, 0($t3)
	sw $t4, 4($t3)
	sw $t4, 8($t3)
	sw $t4, 12($t3)
	sw $t4, 16($t3)
	sw $t4, 20($t3)
	sw $t4, 24($t3)
	sw $t4, 28($t3)
	sw $t4, 256($t3)
	sw $t4, 260($t3)
	sw $t4, 264($t3)
	sw $t4, 268($t3)
	sw $t4, 272($t3)
	sw $t4, 276($t3)
	sw $t4, 280($t3)
	sw $t4, 284($t3)
	jr $ra

##########################################################################################
#End of platform functionality


#Helper functions to and method of CLEAR_SCREEN
#####################################################################################3
CLEAR_SCREEN:
	#Push return address register to stack pointer
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	li $t0, BASE_ADDRESS
	li $t1, 16384
	li $t2, 0
	li $t3, BLACK
	jal CLEAR_PIXELS
	#Pop and return address pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

#Helper function to CLEAR_SCREEN, loops through the entire screen memory to make the pixel black
CLEAR_PIXELS:
#Push address of return to the stack
#Push the return address and jump to the pixel loop
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	j PIXEL_LOOP
	
#Ends the above loop to clear all the pixels from the screen
PIXEL_LOOP:
	#End the loop in case we have reached over our display addresses
	bge  $t2, $t1, END_PIXEL_LOOP
	#Add base address (t0) and offset (t2) and store the result in t4
	add $t4, $t0, $t2
	#Load black to the address stored in t4
	sw $t3, 0($t4)
	#Iterative loop
	addi $t2, $t2, 4
	j PIXEL_LOOP

END_PIXEL_LOOP:
#Pop the address of return and return to it
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#Initializes all arrays to only have values of 0 so we don't lose space in our arrays
CLEAR_ARRAYS:
	li $t0, 0
	li $t1, 200
	la $t2, Enemy_Position_Array
	la $t3, Platform_Position_Array
	la $t4, BULLET_ARRAY
	la $t5, Bullet_Direction
	j CLEAR_ARRS
	
#Called by the above method, clears all arrays
CLEAR_ARRS:
	beq $t0, $t1, RETURN_TO_CALLER
	sw $zero, 0($t2)
	sw $zero, 0($t3) 
	sw $zero, 0($t4) 
	sw $zero, 0($t5)
	addi $t2, $t2, 4
	addi $t3, $t3, 4
	addi $t4, $t4, 4
	addi $t5, $t5, 4
	addi $t0, $t0, 4
	j CLEAR_ARRS
	
RETURN_TO_CALLER:
	jr $ra
	addi $t0, $t0, 4

##################################################################################
#End of clear function method and helpers

START_MENU:
	#Push return address register to stack pointer
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	jal MAKE_TITLE
	#Wait for user input here
	jal WAIT_FOR_USER
	#Pop and return address pointer
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
#Helper function for START_MENU. Waits for user to press P
WAIT_FOR_USER:
	#Push the return address of the calling function onto the stack
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	j INFINITE_WAITING_LOOP
	#Returns after we've recieved the right input from user
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
#Helper function for ridding the start menu, 
#recieves an address to the memory area where code of letter is stored and returns it
CHECK_LETTER:
	li $t0,  0xffff0000
	lw $t2, 4($t0)
	#Load the code of the button pressed
	subi $sp, $sp, 4
	sw $t2, 0($sp)
	jr $ra
	
INFINITE_WAITING_LOOP:
	li $t0, 0xffff0000
	li $t3, 1
	lw $t1, 0($t0)
	beq $t1, $t3, BRANCH_TO_CHECK_LETTER_START_MENU
	j INFINITE_WAITING_LOOP

BRANCH_TO_CHECK_LETTER_START_MENU:
	jal CHECK_LETTER
	lw $t0, 0($sp)
	addi $sp, $sp, 4
	bne $t0, 112, INFINITE_WAITING_LOOP
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
	
MAKE_TITLE:
	#Push the return address of the calling function onto the stack
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	#Load the base address of the display
	li $t1 BASE_ADDRESS
	li $t3 WHITE
	#Make the letter L (hardcoded to increase performance)
	sw $t3, 1060($t1)
	sw $t3, 1064($t1)
	sw $t3, 1316($t1)
	sw $t3, 1320($t1)
	sw $t3, 1572($t1)
	sw $t3, 1576($t1)
	sw $t3, 1828($t1)
	sw $t3, 1832($t1)
	sw $t3, 2084($t1)
	sw $t3, 2088($t1)
	sw $t3, 2340($t1)
	sw $t3, 2344($t1)
	sw $t3, 2596($t1)
	sw $t3, 2600($t1)
	sw $t3, 2852($t1)
	sw $t3, 2856($t1)
	sw $t3, 3108($t1)
	sw $t3, 3112($t1)
	sw $t3, 3364($t1)
	sw $t3, 3368($t1)
	sw $t3, 3620($t1)
	sw $t3, 3624($t1)
	sw $t3, 3876($t1)
	sw $t3, 3880($t1)
	sw $t3, 3628($t1)
	sw $t3, 3632($t1)
	sw $t3, 3636($t1)
	sw $t3, 3640($t1)
	sw $t3, 3644($t1)
	sw $t3, 3648($t1)
	sw $t3, 3884($t1)
	sw $t3, 3888($t1)
	sw $t3, 3892($t1)
	sw $t3, 3896($t1)
	sw $t3, 3900($t1)
	sw $t3, 3904($t1)
	#Make the letter A (hardcoded to increase performance)
	sw $t3, 1128($t1)
	sw $t3, 1380($t1)
	sw $t3, 1384($t1)
	sw $t3, 1388($t1)
	sw $t3, 1632($t1)
	sw $t3, 1636($t1)
	sw $t3, 1640($t1)
	sw $t3, 1644($t1)
	sw $t3, 1648($t1)
	sw $t3, 1900($t1)
	sw $t3, 1904($t1)
	sw $t3, 1908($t1)
	sw $t3, 2160($t1)
	sw $t3, 2164($t1)
	sw $t3, 2168($t1)
	sw $t3, 2420($t1)
	sw $t3, 2424($t1)
	sw $t3, 2428($t1)
	sw $t3, 2680($t1)
	sw $t3, 2684($t1)
	sw $t3, 2688($t1)
	sw $t3, 2940($t1)
	sw $t3, 2944($t1)	
	sw $t3, 3196($t1)
	sw $t3, 3200($t1)
	sw $t3, 3452($t1)
	sw $t3, 3456($t1)
	sw $t3, 3708($t1)
	sw $t3, 3712($t1)
	sw $t3, 3964($t1)
	sw $t3, 3968($t1)
	sw $t3, 1888($t1)
	sw $t3, 1884($t1)
	sw $t3, 1892($t1)
	sw $t3, 2140($t1)
	sw $t3, 2136($t1)
	sw $t3, 2144($t1)
	sw $t3, 2392($t1)
	sw $t3, 2388($t1)
	sw $t3, 2396($t1)
	sw $t3, 2644($t1)
	sw $t3, 2640($t1)
	sw $t3, 2648($t1)
	sw $t3, 2896($t1)
	sw $t3, 2900($t1)
	sw $t3, 3152($t1)
	sw $t3, 3156($t1)
	sw $t3, 3408($t1)
	sw $t3, 3412($t1)
	sw $t3, 3664($t1)
	sw $t3, 3668($t1)
	sw $t3, 3920($t1)
	sw $t3, 3924($t1)
	sw $t3, 2652($t1)
	sw $t3, 2656($t1)
	sw $t3, 2660($t1)
	sw $t3, 2664($t1)
	sw $t3, 2668($t1)
	sw $t3, 2672($t1)
	sw $t3, 2676($t1)
	sw $t3, 2904($t1)
	sw $t3, 2908($t1)
	sw $t3, 2912($t1)
	sw $t3, 2916($t1)
	sw $t3, 2920($t1)
	sw $t3, 2924($t1)
	sw $t3, 2928($t1)
	sw $t3, 2932($t1)
	sw $t3, 2936($t1)
	#Make the letter S
	sw $t3, 1192($t1)
	sw $t3, 1196($t1)
	sw $t3, 1200($t1)
	sw $t3, 1204($t1)
	sw $t3, 1208($t1)
	sw $t3, 1444($t1)
	sw $t3, 1448($t1)
	sw $t3, 1452($t1)
	sw $t3, 1456($t1)
	sw $t3, 1460($t1)
	sw $t3, 1464($t1)
	sw $t3, 1696($t1)
	sw $t3, 1700($t1)
	sw $t3, 1704($t1)
	sw $t3, 1708($t1)
	sw $t3, 1948($t1)
	sw $t3, 1952($t1)
	sw $t3, 1956($t1)
	sw $t3, 1960($t1)
	sw $t3, 2204($t1)
	sw $t3, 2208($t1)
	sw $t3, 2212($t1)
	sw $t3, 2464($t1)
	sw $t3, 2468($t1)
	sw $t3, 2472($t1)
	sw $t3, 2724($t1)
	sw $t3, 2728($t1)
	sw $t3, 2732($t1)
	sw $t3, 2736($t1)
	sw $t3, 2740($t1)
	sw $t3, 2984($t1)
	sw $t3, 2988($t1)
	sw $t3, 2992($t1)
	sw $t3, 2996($t1)
	sw $t3, 3000($t1)
	sw $t3, 3248($t1)
	sw $t3, 3252($t1)
	sw $t3, 3256($t1)
	sw $t3, 3260($t1)
	sw $t3, 3508($t1)
	sw $t3, 3512($t1)
	sw $t3, 3516($t1)
	sw $t3, 3760($t1)
	sw $t3, 3764($t1)
	sw $t3, 3768($t1)
	sw $t3, 3772($t1)
	sw $t3, 4008($t1)
	sw $t3, 4012($t1)
	sw $t3, 4016($t1)
	sw $t3, 4020($t1)
	sw $t3, 4024($t1)
	#Make the letter T 
	sw $t3, 1224($t1)
	sw $t3, 1228($t1)
	sw $t3, 1232($t1)
	sw $t3, 1236($t1)
	sw $t3, 1240($t1)
	sw $t3, 1244($t1)
	sw $t3, 1248($t1)
	sw $t3, 1252($t1)
	sw $t3, 1256($t1)
	sw $t3, 1260($t1)
	sw $t3, 1264($t1)
	sw $t3, 1268($t1)
	sw $t3, 1480($t1)
	sw $t3, 1484($t1)
	sw $t3, 1488($t1)
	sw $t3, 1492($t1)
	sw $t3, 1496($t1)
	sw $t3, 1500($t1)
	sw $t3, 1504($t1)
	sw $t3, 1508($t1)
	sw $t3, 1512($t1)
	sw $t3, 1516($t1)
	sw $t3, 1520($t1)
	sw $t3, 1524($t1)
	sw $t3, 1512($t1)
	sw $t3, 1516($t1)
	sw $t3, 1508($t1)
	sw $t3, 1504($t1)
	sw $t3, 1756($t1)
	sw $t3, 1760($t1)
	sw $t3, 2012($t1)
	sw $t3, 2016($t1)
	sw $t3, 2268($t1)
	sw $t3, 2272($t1)
	sw $t3, 2524($t1)
	sw $t3, 2528($t1)
	sw $t3, 2780($t1)
	sw $t3, 2784($t1)
	sw $t3, 3036($t1)
	sw $t3, 3040($t1)
	sw $t3, 3292($t1)
	sw $t3, 3296($t1)
	sw $t3, 3548($t1)
	sw $t3, 3552($t1)
	sw $t3, 3804($t1)
	sw $t3, 3808($t1)
	sw $t3, 4060($t1)
	sw $t3, 4064($t1)
	#Make an S
	sw $t3, 6952($t1)
	sw $t3, 6956($t1)
	sw $t3, 6960($t1)
	sw $t3, 6964($t1)
	sw $t3, 6968($t1)
	sw $t3, 7204($t1)
	sw $t3, 7208($t1)
	sw $t3, 7212($t1)
	sw $t3, 7216($t1)
	sw $t3, 7220($t1)
	sw $t3, 7224($t1)
	sw $t3, 7456($t1)
	sw $t3, 7460($t1)
	sw $t3, 7464($t1)
	sw $t3, 7468($t1)
	sw $t3, 7708($t1)
	sw $t3, 7712($t1)
	sw $t3, 7716($t1)
	sw $t3, 7720($t1)
	sw $t3, 7964($t1)
	sw $t3, 7968($t1)
	sw $t3, 7972($t1)
	sw $t3, 8224($t1)
	sw $t3, 8228($t1)
	sw $t3, 8232($t1)
	sw $t3, 8484($t1)
	sw $t3, 8488($t1)
	sw $t3, 8492($t1)
	sw $t3, 8496($t1)
	sw $t3, 8744($t1)
	sw $t3, 8748($t1)
	sw $t3, 8752($t1)
	sw $t3, 8756($t1)
	sw $t3, 8760($t1)
	sw $t3, 9016($t1)
	sw $t3, 9012($t1)
	sw $t3, 9008($t1)
	sw $t3, 9268($t1)
	sw $t3, 9264($t1)
	sw $t3, 9260($t1)
	sw $t3, 9256($t1)
	sw $t3, 9520($t1)
	sw $t3, 9516($t1)
	sw $t3, 9512($t1)
	sw $t3, 9508($t1)
	sw $t3, 3772($t1)
	sw $t3, 9772($t1)
	sw $t3, 9768($t1)
	sw $t3, 9764($t1)
	sw $t3, 9760($t1)
	sw $t3, 9756($t1)
	#Make the letter T 
	sw $t3, 6984($t1)
	sw $t3, 6988($t1)
	sw $t3, 6992($t1)
	sw $t3, 6996($t1)
	sw $t3, 7000($t1)
	sw $t3, 7004($t1)
	sw $t3, 7008($t1)
	sw $t3, 7012($t1)
	sw $t3, 7016($t1)
	sw $t3, 7020($t1)
	sw $t3, 7240($t1)
	sw $t3, 7244($t1)
	sw $t3, 7248($t1)
	sw $t3, 7252($t1)
	sw $t3, 7256($t1)
	sw $t3, 7260($t1)
	sw $t3, 7264($t1)
	sw $t3, 7268($t1)
	sw $t3, 7272($t1)
	sw $t3, 7276($t1)
	sw $t3, 7512($t1)
	sw $t3, 7516($t1)
	sw $t3, 7768($t1)
	sw $t3, 7772($t1)
	sw $t3, 8024($t1)
	sw $t3, 8028($t1)
	sw $t3, 8280($t1)
	sw $t3, 8284($t1)
	sw $t3, 8536($t1)
	sw $t3, 8540($t1)
	sw $t3, 8792($t1)
	sw $t3, 8796($t1)
	sw $t3, 9048($t1)
	sw $t3, 9052($t1)
	sw $t3, 9304($t1)
	sw $t3, 9308($t1)
	sw $t3, 9560($t1)
	sw $t3, 9564($t1)
	sw $t3, 9816($t1)
	sw $t3, 9820($t1)
	sw $t3, 10072($t1)
	sw $t3, 10076($t1)
	#Write N
	sw $t3, 7044($t1)
	sw $t3, 7048($t1)
	sw $t3, 7052($t1)
	sw $t3, 7084($t1)
	sw $t3, 7088($t1)
	sw $t3, 7300($t1)
	sw $t3, 7304($t1)
	sw $t3, 7340($t1)
	sw $t3, 7344($t1)
	sw $t3, 7308($t1)
	sw $t3, 7312($t1)
	sw $t3, 7556($t1)
	sw $t3, 7560($t1)
	sw $t3, 7596($t1)
	sw $t3, 7600($t1)
	sw $t3, 7564($t1)
	sw $t3, 7568($t1)
	sw $t3, 7572($t1)
	sw $t3, 7812($t1)
	sw $t3, 7816($t1)
	sw $t3, 7852($t1)
	sw $t3, 7856($t1)
	sw $t3, 7824($t1)
	sw $t3, 7828($t1)
	sw $t3, 7832($t1)
	sw $t3, 8068($t1)
	sw $t3, 8072($t1)
	sw $t3, 8108($t1)
	sw $t3, 8112($t1)
	sw $t3, 8084($t1)
	sw $t3, 8088($t1)
	sw $t3, 8092($t1)
	sw $t3, 8324($t1)
	sw $t3, 8328($t1)
	sw $t3, 8344($t1)
	sw $t3, 8348($t1)
	sw $t3, 8352($t1)
	sw $t3, 8364($t1)
	sw $t3, 8368($t1)
	sw $t3, 8620($t1)
	sw $t3, 8624($t1)
	sw $t3, 8876($t1)
	sw $t3, 8880($t1)
	sw $t3, 8580($t1)
	sw $t3, 8584($t1)
	sw $t3, 8604($t1)
	sw $t3, 8608($t1)
	sw $t3, 8612($t1)
	sw $t3, 8836($t1)
	sw $t3, 8840($t1)
	sw $t3, 8864($t1)
	sw $t3, 8868($t1)
	sw $t3, 8872($t1)
	sw $t3, 9092($t1)
	sw $t3, 9096($t1)
	sw $t3, 9124($t1)
	sw $t3, 9128($t1)
	sw $t3, 9132($t1)
	sw $t3, 9136($t1)
	sw $t3, 9352($t1)
	sw $t3, 9348($t1)
	sw $t3, 9384($t1)
	sw $t3, 9388($t1)
	sw $t3, 9392($t1)
	sw $t3, 9604($t1)
	sw $t3, 9608($t1)
	sw $t3, 9644($t1)
	sw $t3, 9648($t1)
	sw $t3, 9860($t1)
	sw $t3, 9864($t1)
	sw $t3, 9900($t1)
	sw $t3, 9904($t1)
	sw $t3, 10116($t1)
	sw $t3, 10120($t1)
	sw $t3, 10156($t1)
	sw $t3, 10160($t1)
	#Write the letter D
	sw $t3, 7108($t1)
	sw $t3, 7112($t1)
	sw $t3, 7116($t1)
	sw $t3, 7364($t1)
	sw $t3, 7368($t1)
	sw $t3, 7372($t1)
	sw $t3, 7376($t1)
	sw $t3, 7620($t1)
	sw $t3, 7624($t1)
	sw $t3, 7628($t1)
	sw $t3, 7632($t1)
	sw $t3, 7636($t1)
	sw $t3, 7640($t1)
	sw $t3, 7876($t1)
	sw $t3, 7880($t1)
	sw $t3, 7884($t1)
	sw $t3, 7892($t1)
	sw $t3, 7896($t1)
	sw $t3, 7900($t1)
	sw $t3, 9608($t1)
	sw $t3, 8132($t1)
	sw $t3, 8136($t1)
	sw $t3, 8140($t1)
	sw $t3, 8152($t1)
	sw $t3, 8156($t1)
	sw $t3, 8160($t1)
	
	sw $t3, 8388($t1)
	sw $t3, 8392($t1)
	sw $t3, 8396($t1)
	sw $t3, 8412($t1)
	sw $t3, 8416($t1)
	sw $t3, 8420($t1)
	
	sw $t3, 8644($t1)
	sw $t3, 8648($t1)
	sw $t3, 8652($t1)
	sw $t3, 8672($t1)
	sw $t3, 8676($t1)
	sw $t3, 8680($t1)
	
	sw $t3, 8900($t1)
	sw $t3, 8904($t1)
	sw $t3, 8908($t1)
	sw $t3, 8932($t1)
	sw $t3, 8936($t1)
	sw $t3, 8940($t1)
	
	sw $t3, 9156($t1)
	sw $t3, 9160($t1)
	sw $t3, 9164($t1)
	sw $t3, 9188($t1)
	sw $t3, 9192($t1)
	sw $t3, 9196($t1)
	
	sw $t3, 9412($t1)
	sw $t3, 9416($t1)
	sw $t3, 9420($t1)
	sw $t3, 9440($t1)
	sw $t3, 9444($t1)
	sw $t3, 9448($t1)
	
	sw $t3, 9668($t1)
	sw $t3, 9672($t1)
	sw $t3, 9676($t1)
	sw $t3, 9692($t1)
	sw $t3, 9696($t1)
	sw $t3, 9700($t1)
	
	sw $t3, 9924($t1)
	sw $t3, 9928($t1)
	sw $t3, 9932($t1)
	sw $t3, 9944($t1)
	sw $t3, 9948($t1)
	sw $t3, 9952($t1)
	
	sw $t3, 10180($t1)
	sw $t3, 10184($t1)
	sw $t3, 10188($t1)
	sw $t3, 10196($t1)
	sw $t3, 10200($t1)
	sw $t3, 10204($t1)
	
	sw $t3, 10436($t1)
	sw $t3, 10440($t1)
	sw $t3, 10444($t1)
	sw $t3, 10448($t1)
	sw $t3, 10452($t1)
	sw $t3, 10456($t1)
	
	sw $t3, 10692($t1)
	sw $t3, 10696($t1)
	sw $t3, 10700($t1)
	sw $t3, 10704($t1)
	sw $t3, 10708($t1)
	
	sw $t3, 10948($t1)
	sw $t3, 10952($t1)
	sw $t3, 10956($t1)
	sw $t3, 10960($t1)
	
	sw $t3, 11204($t1)
	sw $t3, 11208($t1)
	sw $t3, 11212($t1)
	
	#Make the small play control
	
	sw $t3, 11044($t1)
	sw $t3, 11048($t1)
	sw $t3, 11068($t1)
	sw $t3, 11072($t1)
	sw $t3, 11084($t1)
	
	sw $t3, 11300($t1)
	sw $t3, 11312($t1)
	sw $t3, 11316($t1)
	sw $t3, 11328($t1)
	sw $t3, 11340($t1)
	
	sw $t3, 11556($t1)
	sw $t3, 11568($t1)
	sw $t3, 11576($t1)
	sw $t3, 11584($t1)
	sw $t3, 11596($t1)
	sw $t3, 11616($t1)
	sw $t3, 11620($t1)
	sw $t3, 11640($t1)
	sw $t3, 11644($t1)
	sw $t3, 11668($t1)
	sw $t3, 11672($t1)
	
	sw $t3, 11812($t1)
	sw $t3, 11824($t1)
	sw $t3, 11832($t1)
	sw $t3, 11840($t1)
	sw $t3, 11852($t1)
	sw $t3, 11868($t1)
	sw $t3, 11880($t1)
	sw $t3, 11900($t1)
	sw $t3, 11904($t1)
	sw $t3, 11920($t1)
	sw $t3, 11924($t1)
	
	sw $t3, 12068($t1)
	sw $t3, 12080($t1)
	sw $t3, 12088($t1)
	sw $t3, 12096($t1)
	sw $t3, 12108($t1)
	sw $t3, 12120($t1)
	sw $t3, 12140($t1)
	sw $t3, 12160($t1)
	sw $t3, 12164($t1)
	sw $t3, 12168($t1)
	sw $t3, 12172($t1)
	sw $t3, 12176($t1)
	
	sw $t3, 12324($t1)
	sw $t3, 12336($t1)
	sw $t3, 12340($t1)
	sw $t3, 12352($t1)
	sw $t3, 12364($t1)
	sw $t3, 12376($t1)
	sw $t3, 12396($t1)
	sw $t3, 12424($t1)
	
	sw $t3, 12580($t1)
	sw $t3, 12584($t1)
	sw $t3, 12592($t1)
	sw $t3, 12604($t1)
	sw $t3, 12608($t1)
	sw $t3, 12620($t1)
	sw $t3, 12636($t1)
	sw $t3, 12648($t1)
	sw $t3, 12652($t1)
	sw $t3, 12680($t1)
	
	sw $t3, 12848($t1)
	sw $t3, 12896($t1)
	sw $t3, 12900($t1)
	sw $t3, 12912($t1)
	sw $t3, 12936($t1)
	
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	jr $t1
########################################################################################
