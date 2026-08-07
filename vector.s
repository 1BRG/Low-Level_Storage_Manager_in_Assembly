.data

# --- File and Operation tracking ---
num_ops:        .long 0
op_code:        .long 0
curr_op_idx:    .long 0
num_files:      .long 0
curr_file_idx:  .long 0

# --- File attributes ---
file_desc:      .long 0
file_size:      .long 0
blocks_needed:  .long 0

# --- Memory boundaries and state ---
mem_limit:      .long 1024
start_pos:      .long 0
end_pos:        .long 0
counter:        .long 0
last_empty_idx: .long 0
start_idx:      .long 0

# --- Main memory block ---
memory_array:   .space 4096

# --- Formatting Strings ---
scan_fmt_int:   .asciz "%d\n"
fmt_print_add:  .asciz "%d: (%d, %d)\n"
fmt_print_get:  .asciz "(%d, %d)\n"

.text

# =======================================================================
# calc_blocks_needed
# Calculates the number of blocks needed for a given file size.
# Divides size by 8. If there is a remainder, adds 1 block.
# =======================================================================
calc_blocks_needed:   
    pushl %ebp
    movl %esp, %ebp

    xorl %eax, %eax
    xorl %edx, %edx

    movl 8(%ebp), %eax
    movl $8, %ebx
    divl %ebx

    cmpl $0, %edx
    je no_increment
    incl %eax           # Round up if there's a remainder

no_increment:
    popl %ebp
    ret


# =======================================================================
# allocate_blocks
# Fills a contiguous interval in memory_array with the file descriptor.
# =======================================================================
allocate_blocks:
    pushl %ebp
    movl %esp, %ebp
    
    movl 8(%ebp), %ecx
    movl %ecx, file_desc
    xorl %ecx, %ecx
    movl %eax, %ecx
    lea memory_array, %edi

    loop_allocate:
        cmp %ecx, %ebx
        je end_allocate
        
        movl file_desc, %edx
        movl %edx, (%edi, %ecx, 4)
        incl %ecx
        jmp loop_allocate

    end_allocate:
        popl %ebp
        ret


# =======================================================================
# add_file
# Finds the first contiguous free block large enough and allocates it.
# =======================================================================
add_file:
    pushl %ebp
    movl %esp, %ebp
    
    movl 12(%ebp), %eax
    movl %eax, file_size
    movl 8(%ebp), %eax
    movl %eax, file_desc
    
    pushl file_size
    call calc_blocks_needed
    movl %eax, blocks_needed
    popl %ebx
    
    lea memory_array, %edi
    xorl %ecx, %ecx
    
    loop_find_free:
        cmpl %ecx, mem_limit
        je end_add
        
        movl (%edi, %ecx, 4), %ebx
        cmpl $0, %ebx
        jne resume_find_free
        
        # Check if we have enough contiguous free space
        movl %ecx, %ebx
        movl %ecx, %eax
        addl blocks_needed, %ebx
        
        loop_check_contig:
            cmp %ecx, %ebx
            jne check_next_block
            
            # Space found, allocate it
            pushl file_desc
            call allocate_blocks 
            popl %ecx
            popl %ebp
            dec %ebx
            ret

        check_next_block:
            cmp %ecx, mem_limit 
            je end_add
            
            movl (%edi, %ecx, 4), %edx
            cmpl $0, %edx
            jne resume_find_free
            
            inc %ecx
            jmp loop_check_contig
        
        resume_find_free:
            inc %ecx
            jmp loop_find_free

    end_add:
    xorl %eax, %eax
    xorl %ebx, %ebx
    popl %ebp
    ret


# =======================================================================
# get_file
# Finds the start and end indices of a file by its descriptor.
# =======================================================================
get_file:
    pushl %ebp
    movl %esp, %ebp
    
    movl 8(%ebp), %ebx
    movl %ebx, file_desc
    lea memory_array, %edi
    
    loop_find_get:
        cmpl %ecx, mem_limit
        je end_get
        
        movl (%edi, %ecx, 4), %ebx
        cmpl %ebx, file_desc
        jne resume_find_get
        
        movl %ecx, %eax
        
        loop_find_get_end:
            cmp %ecx, mem_limit
            jne check_get_end
            
            movl %ecx, %ebx
            dec %ebx
            popl %ebp
            ret
            
        check_get_end:
            movl (%edi, %ecx, 4), %ebx
            cmp %ebx, file_desc
            je continue_find_get_end
            
            movl %ecx, %ebx
            dec %ebx
            popl %ebp
            ret
            
        continue_find_get_end:
            inc %ecx
            jmp loop_find_get_end

        resume_find_get:
            inc %ecx
            jmp loop_find_get

    end_get:
    xorl %eax, %eax
    xorl %ebx, %ebx
    popl %ebp
    ret


# =======================================================================
# delete_file
# Replaces all blocks matching the given file descriptor with zeros (0).
# =======================================================================
delete_file:
    pushl %ebp
    movl %esp, %ebp
    
    movl 8(%ebp), %ebx
    movl %ebx, file_desc
    lea memory_array, %edi
    xorl %ecx, %ecx
    xorl %edx, %edx
    
    loop_find_del:
        cmpl %ecx, mem_limit
        je end_del
        
        movl (%edi, %ecx, 4), %ebx
        cmpl %ebx, file_desc
        jne resume_find_del
        
        loop_del_blocks:
            cmp %ecx, mem_limit
            jne check_del_end
            popl %ebp
            ret
            
        check_del_end:
            movl (%edi, %ecx, 4), %ebx
            cmp %ebx, file_desc
            je continue_del_blocks
            popl %ebp
            ret
            
        continue_del_blocks:
            movl $0, %ebx
            mov %ebx, (%edi, %ecx, 4)
            inc %ecx
            jmp loop_del_blocks

        resume_find_del:
            inc %ecx
            jmp loop_find_del

    end_del:
    xorl %eax, %eax
    xorl %ebx, %ebx
    popl %ebp
    ret


# =======================================================================
# print_memory
# Iterates through memory and prints contiguous allocated file blocks.
# =======================================================================
print_memory:
    xorl %ecx, %ecx
    lea memory_array, %edi
    
    loop_print_mem:
        cmpl %ecx, mem_limit
        je end_print
        
        movl (%edi, %ecx, 4), %ebx
        cmpl $0, %ebx
        je resume_print_mem
        
        movl %ebx, file_desc
        movl %ecx, %eax
        
        loop_print_blocks:
            cmp %ecx, mem_limit
            jne check_print_end
            
            dec %ecx
            pushl %ecx
            pushl %eax
            pushl file_desc
            pushl $fmt_print_add
            call printf
            addl $16, %esp
            ret
            
        check_print_end:
            movl (%edi, %ecx, 4), %ebx
            cmp %ebx, file_desc
            je continue_print_blocks
            
            dec %ecx
            movl %ecx, start_idx
            
            pushl %ecx
            pushl %eax
            pushl file_desc
            pushl $fmt_print_add
            call printf
            
            movl start_idx, %ecx
            addl $16, %esp
            jmp resume_print_mem
            
        continue_print_blocks:
            incl %ecx
            jmp loop_print_blocks

        resume_print_mem:
            incl %ecx
            jmp loop_print_mem

    end_print:
    xorl %eax, %eax
    xorl %ebx, %ebx
    ret


# =======================================================================
# defragment_memory
# Shifts allocated blocks to the left to eliminate free gaps.
# =======================================================================
defragment_memory:
    lea memory_array, %edi
    xorl %ecx, %ecx
    
    movl %ecx, last_empty_idx
    movl $1045, last_empty_idx
    
    loop_def_find_used:
        cmpl %ecx, mem_limit
        je end_defrag
        
        movl (%edi, %ecx, 4), %ebx
        cmpl $0, %ebx
        je resume_find_defrag_blocks
        cmpl $1045, last_empty_idx
        je resume_find_defrag_blocks
        
        loop_def_move_blocks:
            cmp %ecx, mem_limit
            jne check_def_bounds
            ret
            
        check_def_bounds:
            movl (%edi, %ecx, 4), %ebx
            cmp $0, %ebx
            je resume_find_defrag_blocks
            
        continue_def_move:
            movl last_empty_idx, %ebx
            incl last_empty_idx
            movl (%edi, %ecx, 4), %eax
            movl %eax, (%edi, %ebx, 4)
            movl $0, %ebx
            movl %ebx, (%edi, %ecx, 4)
            inc %ecx
            jmp loop_def_move_blocks

        resume_find_defrag_blocks:
            cmpl $1045, last_empty_idx
            jne def_update_empty_idx
            cmpl $0, (%edi, %ecx, 4)
            jne def_update_empty_idx
            movl %ecx, last_empty_idx
            
        def_update_empty_idx:
        def_skip:
            inc %ecx
            jmp loop_def_find_used

    end_defrag:
    xorl %eax, %eax
    xorl %ebx, %ebx
    ret


# =======================================================================
# MAIN FUNCTION
# Parses standard input for operations and directs execution.
# =======================================================================
.global main

main:
    # Read number of operations
    pushl $num_ops
    pushl $scan_fmt_int
    call scanf
    addl $8, %esp
    
    xorl %ecx, %ecx
    
    loop_operations:
        cmp num_ops, %ecx
        je exit_program
        
        movl %ecx, curr_op_idx
        pushl $op_code
        pushl $scan_fmt_int
        call scanf
        addl $8, %esp
        
        cmpl $1, op_code
        jne check_op_get

        # --- OPERATION 1: ADD ---
        pushl $num_files
        pushl $scan_fmt_int
        call scanf
        addl $8, %esp

        xorl %edx, %edx
        loop_add_files:
            cmp %edx, num_files
            je continue_loop_ops
            movl %edx, curr_file_idx
            
            # Read descriptor and size
            pushl $file_desc
            pushl $scan_fmt_int
            call scanf
            addl $8, %esp

            pushl $file_size
            pushl $scan_fmt_int
            call scanf
            addl $8, %esp

            # Execute Add
            pushl file_size
            pushl file_desc
            call add_file
            addl $8, %esp
            
            # Print allocation result
            pushl %ebx
            pushl %eax
            pushl file_desc
            pushl $fmt_print_add
            call printf
            addl $16, %esp

            movl curr_file_idx, %edx
            inc %edx
            jmp loop_add_files

    check_op_get:
        cmpl $2, op_code
        jne check_op_delete

        # --- OPERATION 2: GET ---
        exec_get:
        pushl $file_desc
        pushl $scan_fmt_int
        call scanf
        addl $8, %esp

        pushl file_desc
        call get_file
        popl %edx
        
        pushl %ebx
        pushl %eax
        pushl $fmt_print_get
        call printf
        addl $12, %esp
        jmp continue_loop_ops

    check_op_delete:
        cmpl $3, op_code
        jne check_op_defrag

        # --- OPERATION 3: DELETE ---
        pushl $file_desc
        pushl $scan_fmt_int
        call scanf
        addl $8, %esp
        
        pushl file_desc
        call delete_file
        popl %edx
        call print_memory
        jmp continue_loop_ops

    check_op_defrag:
        cmpl $4, op_code
        jne continue_loop_ops
        
        # --- OPERATION 4: DEFRAGMENT ---
        exec_defrag:
        call defragment_memory
        call print_memory

    continue_loop_ops:
        movl curr_op_idx, %ecx
        inc %ecx
        jmp loop_operations

exit_program:
    pushl $0
    call fflush
    popl %ebx
    
    movl $1, %eax
    xorl %ebx, %ebx
    int $0x80