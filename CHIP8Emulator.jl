using Random

# Emulator State

### Current Opcode
opcode = UInt16(0)

### 4k Memory
### 0x000-0x1FF - Chip 8 interpreter (contains font set in emu)
### 0x050-0x0A0 - Used for the built in 4x5 pixel font set (0-F)
### 0x200-0xFFF - Program ROM and work RAM
memorybank = zeros(UInt8,4096)

### Keyboard
key = zeros(UInt8,16)

### 16 8-bit registers
registers_V = zeros(UInt16,16)

### Register I
register_I = UInt16(0)

### Register PC (Program Counter)
register_pc = UInt16(0)

### GFX Buffer
gfx = zeros(UInt8,2048) ## 64 * 32

### Timers
delay_timer = UInt8(0)
sound_timer = UInt8(0)

### Stack
stack = zeros(UInt16,16)
stackpointer = UInt16(0)

### Draw Flag
drawFlag = false;

DebugOutput = false
function DebugPrint(message)
   if(DebugOutput)
        print(message)
    end
end
function DebugPrintln(message)
   if(DebugOutput)
        println(message)
    end
end

function SetVX(X, value)
    registers_V[X+1] = value
end

function ReadVX(X)
    return registers_V[X+1]
end

## Font Set
chip8_fontset =
[
    0xF0, 0x90, 0x90, 0x90, 0xF0, ##0
    0x20, 0x60, 0x20, 0x20, 0x70, ##1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, ##2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, ##3
    0x90, 0x90, 0xF0, 0x10, 0x10, ##4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, ##5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, ##6
    0xF0, 0x10, 0x20, 0x40, 0x40, ##7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, ##8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, ##9
    0xF0, 0x90, 0xF0, 0x90, 0x90, ##A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, ##B
    0xF0, 0x80, 0x80, 0x80, 0xF0, ##C
    0xE0, 0x90, 0x90, 0x90, 0xE0, ##D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, ##E
    0xF0, 0x80, 0xF0, 0x80, 0x80  ##F
];

function DecodeOpcode()
    global register_pc
    global delay_timer
    global sound_timer
    global memorybank
    global stack
    global stackpointer
    global register_I
    global drawFlag
    global gfx
    
    maskedcode = opcode & 0xF000
    #DebugPrint("maskedcode: ")
    #DebugPrintln(maskedcode)
    
    ### 1NNN - Jump Instruction to NNN
    if(maskedcode == 0x1000)
        DebugPrintln("1NNN")
        register_pc = opcode & 0x0FFF
    
    ### 2NNN - Call subroutine at NNN
    elseif(maskedcode == 0x2000)
        DebugPrintln("2NNN")
        stack[stackpointer+1] = register_pc
        stackpointer = stackpointer + 1
        register_pc = opcode & 0x0FFF;
    
    ### 3XNN - Skip if register VX is equal to NN
    elseif(maskedcode == 0x3000)
        DebugPrintln("3XNN")
        if(registers_V[((opcode & 0x0F00) >> 8) + 1] == (opcode & 0x00FF) )
            register_pc = register_pc + 4
        else 
            register_pc = register_pc + 2
        end
    
    ### 4XNN - Skip if register VX is NOT equal to NN
    elseif(maskedcode == 0x4000)
        DebugPrintln("4XNN")
        if(registers_V[((opcode & 0x0F00) >> 8) + 1] != (opcode & 0x00FF) )
            register_pc = register_pc + 4
        else 
            register_pc = register_pc + 2
        end
    
    ### 5XY0 - Skip if register VX is equal to VY
    elseif(maskedcode == 0x5000)
        DebugPrintln("5XY0")
        if(ReadVX((opcode & 0x0F00) >> 8) == ReadVX( (opcode & 0x00F0) >> 4) )
            register_pc = register_pc + 4
        else 
            register_pc = register_pc + 2
        end
    
    ### 6XNN - Set VX to NN
    elseif(maskedcode == 0x6000)
        DebugPrintln("6XNN")
        SetVX( (opcode & 0x0F00) >> 8, opcode & 0x00FF)
        register_pc = register_pc + 2;
    
    ### 7XNN - Add NN to VX
    elseif(maskedcode == 0x7000)
        DebugPrintln("7XNN")
        registers_V[((opcode & 0x0F00) >> 8) + 1] += opcode & 0x00FF;
        register_pc = register_pc + 2;
    
    ### 8---
    elseif(maskedcode == 0x8000)
        subcode = opcode & 0x000F
        
        # 0x8XY0: Sets VX to VY
        if(subcode == 0x0000)
            DebugPrintln("8XY0")
            registers_V[ ((opcode & 0x0F00) >> 8) + 1 ] = registers_V[((opcode & 0x00F0) >> 4) + 1]
            register_pc = register_pc + 2
            
         # 0x8XY1: Sets VX to -VX OR VY-
        elseif(subcode == 0x0001)
            DebugPrintln("8XY1")
            registers_V[ ((opcode & 0x0F00) >> 8) + 1 ] |= registers_V[((opcode & 0x00F0) >> 4) + 1]
            register_pc = register_pc + 2  
            
         # 0x8XY2: Sets VX to VX AND VY
        elseif(subcode == 0x0002)
            DebugPrintln("8XY2")
            registers_V[ ((opcode & 0x0F00) >> 8) + 1 ] &= registers_V[((opcode & 0x00F0) >> 4) + 1]
            register_pc = register_pc + 2  
            
        # 0x8XY3: Sets VX to VX XOR VY
        elseif(subcode == 0x0003) 
            DebugPrintln("8XY3")
            registers_V[ ( (opcode & 0x0F00) >> 8) + 1 ] ^= registers_V[ ((opcode & 0x00F0) >> 4) + 1]
            register_pc = register_pc + 2  
        
        # 0x8XY4 Add VX to VY
        elseif(subcode == 0x0004) 
            DebugPrintln("8XY4")
            if(registers_V[ ( (opcode & 0x00F0) >> 4) + 1] > (0xFF - registers_V[( (opcode & 0x0F00) >> 8) + 1])) 
                registers_V[0xF + 1] = 1 # Mark that there is a carry
            else 
                registers_V[0xF + 1] = 0
            end
            registers_V[ ((opcode & 0x0F00) >> 8) + 1] += registers_V[((opcode & 0x00F0) >> 4) + 1]
            register_pc = register_pc + 2  
            
        # 0x8XY5  VY is subbed from VX
        elseif(subcode == 0x0005)
            DebugPrintln("8XY5")
            if(registers_V[((opcode & 0x00F0) >> 4) + 1] > (0xFF - registers_V[((opcode & 0x0F00) >> 8) + 1])) 
                registers_V[0xF+1] = 0 # Mark that there is a borrow
            else 
                registers_V[0xF+1] = 1
            end
            registers_V[((opcode & 0x0F00) >> 8)+1] -= registers_V[((opcode & 0x00F0) >> 4)+1]
            register_pc = register_pc + 2 
            
        # 0x8XY6: Shift VX right by one. Store LSB in VF
        elseif(subcode == 0x0006)
            DebugPrintln("8XY6")
            registers_V[0xF+1] = registers_V[((opcode & 0x0F00) >> 8)+1] & 0x1
            registers_V[((opcode & 0x0F00) >> 8)+1] >>= 1
            register_pc = register_pc + 2
            
        # 0x8XY7: Sets VX to VY minus VX.
        elseif(subcode == 0x0007)
            DebugPrintln("8XY7")
            if(registers_V[((opcode & 0x0F00) >> 8)+1] > registers_V[((opcode & 0x00F0) >> 4)+1])
                registers_V[0xF+1] = 0 # Mark the borrow
            else
                registers_V[0xF+1] = 1
            end
            registers_V[((opcode & 0x0F00) >> 8)+1] = registers_V[((opcode & 0x00F0) >> 4)+1] - registers_V[((opcode & 0x0F00) >> 8)+1]
            register_pc = register_pc + 2
            
        # 0x8XYE: Shifts VX left by one.
        elseif(subcode == 0x000E)
            DebugPrintln("8XYE")
            registers_V[0xF+1] = registers_V[((opcode & 0x0F00) >> 8)+1] >> 7
            registers_V[((opcode & 0x0F00) >> 8)+1] <<= 1
            register_pc = register_pc + 2
        else
            println(string("Unknown Opcode:", string(maskedcode)) )
        end       
    
    ### 9XY0 - Skips next instruction if VX != VY
    elseif(maskedcode == 0x9000)
        DebugPrintln("9XY0")
        if(registers_V[((opcode & 0x0F00) >> 8) + 1] != registers_V[((opcode & 0x00F0) >> 4) + 1])
            pc = register_pc + 4;
        else
            pc = register_pc + 2;
        end
    
    ### ANNN - Set I to NNN
    elseif(maskedcode == 0xA000)
        DebugPrintln("ANNN")
        register_I = opcode & 0x0FFF
        register_pc = register_pc + 2
        
    ### BNNN - Jumps to the address NNN + V0
    elseif(maskedcode == 0xB000)
        DebugPrintln("BNNN")
        NNN = opcode & 0x0FFF
        newAddress = NNN+registers_V[0+1]
        register_pc = newAddress
    
    ### CXNN - Sets VX to the result of a bitwise and operation on a 
    ##         random number (0-255) and NN
    elseif(maskedcode == 0xC000)
        DebugPrintln("CXNN")
        registers_V[((opcode & 0x0F00) >> 8)+1] = (rand(UInt8) % 0xFF) & (opcode & 0x00FF);
        register_pc = register_pc + 2
    
    ### DXYN - Draw Sprite
    elseif(maskedcode == 0xD000)
        DebugPrintln("DXYN")
        x      = registers_V[((opcode & 0x0F00) >> 8) + 1];
        y      = registers_V[((opcode & 0x00F0) >> 4) + 1];
        height = opcode & 0x000F;
        pixel  = 0

        registers_V[0xF+1] = 0;
        for yline = 0:height-1
            pixel = memorybank[register_I + yline + 1];
            for xline = 0:7
                if((pixel & (0x80 >> xline)) != 0)
                    if(gfx[(x + xline + ((y + yline) * 64)) + 1] == 1)
                        registers_V[0xF+1] = 1;                                    
                    end
                    gfx[x + xline + ((y + yline) * 64) + 1] = 1;
                end
            end
        end
        
        drawFlag = true;
        register_pc = register_pc + 2
        
    ### EX9E and EXA1 - Key Press Up and Down Handling
    elseif(maskedcode == 0xE000)
        subcode = opcode & 0x00FF
        
        # EX9E - Skips the next instruction if key in VX is pressed
        if(subcode == 0x009E)
            DebugPrintln("EX9E")
            if(key[registers_V[((opcode & 0x0F00) >> 8)+1]+1] != 0)
                register_pc = register_pc + 4
            else
                register_pc = register_pc + 2
            end
            
        # EXA1 Skips the instruction if the key stored in VX isnt pressed
        elseif(subcode == 0x00A1)
            DebugPrintln("EXA1")
            if(key[registers_V[((opcode & 0x0F00) >> 8)+1]+1] == 0)
                register_pc = register_pc + 4
            else
                register_pc = register_pc + 2
            end
        else
            println(string("Unknown Opcode:", string(maskedcode)) )
        end
    
    ### FX Opcodes
    elseif(maskedcode == 0xF000)
        endbits = opcode & 0x00FF
        
        # FX07: Set VX to value of delay timer
        if(endbits == 0x0007)
            DebugPrintln("FX07")
            registers_V[((opcode & 0x0F00) >> 8) + 1] = delay_timer
            register_pc = register_pc + 2
            
        # FX0A - Wait for keypress and store in VX
        elseif ( endbits == 0x000A)
            DebugPrintln("FX0A")
            keyPress = false;
            for i = 0:15
                if(key[i] != 0)
                    registers_V[((opcode & 0x0F00) >> 8)+1] = i
                    keyPress = true;
                end
            end
            
            if(!keyPress)
                return;
            end
            register_pc = register_pc + 2
            
        # FX15: Sets the delay timer to VX
        elseif ( endbits == 0x0015)
            DebugPrintln("FX15")
            delay_timer = registers_V[((opcode & 0x0F00) >> 8)+1]
            register_pc = register_pc + 2
            
        # FX18 Sets the sound timer to VX
        elseif( endbits == 0x0018)
            DebugPrintln("FX18")
            sound_timer = registers_V[((opcode & 0x0F00) >> 8)+1]
            register_pc = register_pc + 2
            
        # FX1E: Adds VX to I
        elseif(endbits == 0x001E)
            DebugPrintln("FX1E")
            if(register_I + registers_V[((opcode & 0x0F00) >> 8) + 1] > 0xFFF)
                registers_V[0xF+1] = 1
            else
                registers_V[0xF+1] = 0
            end
            register_I = register_I + registers_V[((opcode & 0x0F00) >> 8)+1]
            register_pc = register_pc + 2
            
        # FX29 Sets I to the location of the sprite for the character in VX
        elseif(endbits == 0x0029)
            DebugPrintln("FX29")
            register_I  = registers_V[((opcode & 0x0F00) >> 8)+1] * 0x5;
            register_pc = register_pc + 2
            
        # Stores the binary coded decimal representation of VX at the address I -> I+2
        elseif(endbits == 0x0033)
            DebugPrintln("FX33")
            memorybank[register_I + 1]     =  registers_V[((opcode & 0x0F00) >> 8)+1] / 100
            memorybank[register_I + 1 + 1] = (registers_V[((opcode & 0x0F00) >> 8)+1] / 10) % 10
            memorybank[register_I + 2 + 1] = (registers_V[((opcode & 0x0F00) >> 8)+1] % 100) % 10   
            
        # FX55 Stores V0 to VX in memory starting at address I
        elseif(endbits==0x0055)
            DebugPrintln("FX55")
            i = 0
            while i <= ((opcode & 0x0F00) >> 8)
                memorybank[register_I + i + 1] = registers_V[i + 1]
                # On the original interpreter, when the operation is done, I = I + X + 1.
                register_I += ((opcode & 0x0F00) >> 8) + 1
                register_pc = register_pc + 2   
                i = i + 1
            end
            
        # FX65 Fill V0 to VX with values from memory starting at address I
        elseif(endbits==0x0065)
            DebugPrintln("FX65")
            i = 0
            while i <= ((opcode & 0x0F00) >> 8)
                registers_V[i+1] = memorybank[register_I + i + 1]
                i = i + 1
            end

            # On the original interpreter, when the operation is done, I = I + X + 1.
            register_I += ((opcode & 0x0F00) >> 8) + 1
            register_pc = register_pc + 2
        else
            println(string("Unknown Opcode:", string(maskedcode)) )
        end
        
    ### Special Cases
    elseif(maskedcode == 0x0000)
        clippedCode = opcode & 0x000F
        
        # 0000 CLear Screen
        if(clippedCode == 0x0000)
            DebugPrintln("0000")
            fill!(gfx, zero(UInt8))
            drawFlag = true
            register_pc= register_pc + 2
        
         ##Subroutine Return
        elseif(clippedCode == 0x000E)
            DebugPrintln("0x000E")
            stackpointer = stackpointer-1
            register_pc = stack[stackpointer+1]
            register_pc = register_pc + 2
        else
            println(string("Unknown Opcode:", string(maskedcode)) )
        end
    else
        println(string("Unknown Opcode:", string(maskedcode)) )
    end
end

function LoadProgram(filename::String)
    io            = open(filename, "r")
    programLength = filesize(filename);
    last          = 0xFF;
    if( (4096-512) < programLength)
        println("Program too big for memory")
    else
        for i = 0:programLength-1
            d = UInt16(read(io,UInt8))
            #@show d
            memorybank[1+i+512] = d
            if(i%2 == 1)
                newcode = UInt16(last << 8 | d)
                #@show i
                #@show newcode
            end
            last = d
        end
    end
    close(io)
end

LoadProgram("invaders.c8")

# Initialise OpenGL Window
import GLFW
using ModernGL, GeometryTypes
using GLAbstraction


posUniformLoc = -1
window = -1
vertices = -1
function InitOpenGL()
global posUniformLoc
global window
global vertices
    
    
window_hint = [
    (GLFW.SAMPLES,      4),
    (GLFW.DEPTH_BITS,   0),

    (GLFW.ALPHA_BITS,   8),
    (GLFW.RED_BITS,     8),
    (GLFW.GREEN_BITS,   8),
    (GLFW.BLUE_BITS,    8),
    (GLFW.STENCIL_BITS, 0),
    (GLFW.AUX_BUFFERS,  0),
    (GLFW.CONTEXT_VERSION_MAJOR, 3),# minimum OpenGL v. 3
    (GLFW.CONTEXT_VERSION_MINOR, 0),# minimum OpenGL v. 3.0
    (GLFW.OPENGL_PROFILE, GLFW.OPENGL_ANY_PROFILE),
    (GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE),
]

for (key, value) in window_hint
    GLFW.WindowHint(key, value)
end

window = GLFW.CreateWindow(800, 600, "Drawing polygons 1")
GLFW.MakeContextCurrent(window)
GLFW.SetInputMode(window, GLFW.STICKY_KEYS, GL_TRUE)

vao = Ref(GLuint(0))
glGenVertexArrays(1, vao)
glBindVertexArray(vao[])

MinX = 0.0
MinY = 0.0
MaxX = -2.0/64.0;
MaxY = -2.0/32.0;
vertices = Point2f0[(MinX, MaxY), (MaxX, MinY), (MinX, MinY), (MinX, MaxY), (MaxX, MinY), (MaxX, MaxY)] # note Float32

vbo = Ref(GLuint(0))   # initial value is irrelevant, just allocate space
glGenBuffers(1, vbo)
glBindBuffer(GL_ARRAY_BUFFER, vbo[])
glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

vertex_source = """
#version 150
uniform vec4 location;
in vec2 position;
void main()
{
    gl_Position = vec4(position + location.xy, 0.0, 1.0);
}
"""

fragment_source = """
# version 150
out vec4 outColor;
void main()
{
    outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
"""

vertex_shader = glCreateShader(GL_VERTEX_SHADER)
glShaderSource(vertex_shader, vertex_source)  # nicer thanks to GLAbstraction
glCompileShader(vertex_shader)
status = Ref(GLint(0))
glGetShaderiv(vertex_shader, GL_COMPILE_STATUS, status)
if status[] != GL_TRUE
    buffer = Array(UInt8, 512)
    glGetShaderInfoLog(vertex_shader, 512, C_NULL, buffer)
    @error "$(bytestring(buffer))"
end

fragment_shader = glCreateShader(GL_FRAGMENT_SHADER)
glShaderSource(fragment_shader, fragment_source)
glCompileShader(fragment_shader)
status = Ref(GLint(0))
glGetShaderiv(fragment_shader, GL_COMPILE_STATUS, status)
if status[] != GL_TRUE
    buffer = Array(UInt8, 512)
    glGetShaderInfoLog(fragment_shader, 512, C_NULL, buffer)
    @error "$(bytestring(buffer))"
end

shader_program = glCreateProgram()
glAttachShader(shader_program, vertex_shader)
glAttachShader(shader_program, fragment_shader)
glBindFragDataLocation(shader_program, 0, "outColor") # optional

glLinkProgram(shader_program)
glUseProgram(shader_program)

pos_attribute = glGetAttribLocation(shader_program, "position")
glVertexAttribPointer(pos_attribute, length(eltype(vertices)),
                      GL_FLOAT, GL_FALSE, 0, C_NULL)
glEnableVertexAttribArray(pos_attribute)
posUniformLoc = glGetUniformLocation(shader_program, "location");
end

function InitialiseChip8()
    global register_pc
    global opcode
    global register_I
    global stackpointer
    global gfx
    global stack
    global registers_V
    global memorybank
    global sound_timer
    global delay_timer
    
    register_pc     = 0x200;  ## Program counter starts at 0x200
    opcode          = 0;      ## Reset current opcode	
    register_I      = 0;      ## Reset index register
    stackpointer    = 0;      ## Reset stack pointer
    
    # Clear Display
    fill!(gfx, zero(UInt8))
    # Clear Stack
    fill!(stack, zero(UInt16))
    # Clear Registers
    fill!(registers_V, zero(UInt16))
    # Clear Memory
    fill!(memorybank, zero(UInt8))
    
    ## Load Fontset
    for i = 1:80
        memorybank[i] = chip8_fontset[i];
    end
        
    # Reset Timers
    sound_timer = 0
    delay_timer = 0
    # Load Program into memory starting at address 512
    LoadProgram("invaders.c8")
end

function EmulationStep()
    global sound_timer
    global delay_timer
    global opcode
    
    ## Fetch OpCode
    #@show register_pc
    opcode = UInt16(UInt16(memorybank[register_pc+1]) << 8 | UInt16(memorybank[register_pc + 2]))
    ## Decode and Execute OpCode
    DecodeOpcode()
    
    ## Update Timers
    if(delay_timer > 0) delay_timer = delay_timer -1 end
    if(sound_timer > 0) 
        if(sound_timer == 1) print("beep") end
        sound_timer = sound_timer-1
    end
end

frame = 0
function DrawScreen()
    global frame
    
    IJulia.clear_output()
    println("Draw Screen...")
    println(frame)
    frame += 1
    
    fullstring = ""
    for y = 1:31
        for x =1:64
            if(gfx[(y*64) + x] == 0) 
                fullstring = string(fullstring,"■");
            else 
                fullstring = string(fullstring," ");
            end
        end
        fullstring = string(fullstring,"\n");
    end
    fullstring = string(fullstring,"\n");
    
    println(fullstring)
end



function DrawSceneOpenGL()
    global window
    global vertices
    global posUniformLoc
    
    glClearColor(0,0,0,0)
    glClear(GL_COLOR_BUFFER_BIT)
    
    for y = 1:31
        for x =1:64
            glUniform4f(posUniformLoc, -1.0 * (1.0 - ((x-1) * (2.0/64.0))), 1.0 - ((y-1) * (2.0/32.0)), 0.0, 0.0);
            if(gfx[(y*64) + x] == 0) 
                glDrawArrays(GL_TRIANGLES, 0, 6)
            end
        end
    end

    GLFW.SwapBuffers(window)
    GLFW.PollEvents()    
end

function GetKeyState(key)
     return ccall((:GetKeyPressed, "WindowsKeypressLibrary.dll"), Bool, (Cuchar,), key)
end

function ReadKeyState()
    key[1] = GetKeyState('1')
    key[2] = GetKeyState('2')
    key[3] = GetKeyState('3')
    key[4] = GetKeyState('4')
    key[5] = GetKeyState('Q')
    key[6] = GetKeyState('W')
    key[7] = GetKeyState('E')
    key[8] = GetKeyState('R')
    key[9] = GetKeyState('A')
    key[10] = GetKeyState('S')
    key[11] = GetKeyState('D')
    key[12] = GetKeyState('F')
    key[13] = GetKeyState('Z')
    key[14] = GetKeyState('X')
    key[15] = GetKeyState('C')
    key[16] = GetKeyState('V')
end

function Chip8()
    global drawFlag
    global window
    
    InitialiseChip8()
    InitOpenGL()
    while !GLFW.WindowShouldClose(window)
        EmulationStep()
        if(drawFlag)
            DrawSceneOpenGL()
            #sleep(0.1)
            drawFlag = false
        end
        ReadKeyState()
    end 
    GLFW.DestroyWindow(window) 
end


Chip8()




