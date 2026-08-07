.data

# --- File handling specific ---
slash_str:          .asciz "/"
file_stats:         .space 4096
dir_data:           .space 4096
file_name:          .space 4096
folder_path:        .space 4096
total_bytes_read:   .long 0
file_num:           .byte 0
next_entry_offset:  .long 0

# --- Temporary variables & Counters ---
temp_val1:          .long 0
temp_val2:          .long 0
temp_val3:          .long 0
temp_def_val:       .long 0
counter:            .long 0

# --- Matrix structure ---
row_size:           .long 1024
total_matrix_size:  .long 1048576
row_end_limit:      .long 0
curr_col:           .long 0
mem_limit:          .long 0
memory_array:       .space 4194304

# --- Loop and state trackers ---
last_empty_idx:     .long 0
start_idx:          .long 0
curr_file_idx:      .long 0
num_files:          .long 0
op_code:            .long 0
curr_op_idx:        .long 0
num_ops:            .long 0
start_pos:          .long 0
end_pos:            .long 0

# --- File attributes ---
file_desc:          .long 0
file_size:          .long 0
blocks_needed:      .long 0

# --- Formats ---
scan_fmt_int:       .asciz "%d\n"
scan_fmt_str:       .asciz "%s\n"
dbg_fmt_int:        .asciz "%d\n"
dbg_fmt_str:        .asciz "%s\n"
fmt_print_add:      .asciz "%d: ((%d, %d), (%d, %d))\n"
fmt_print_get:      .asciz "((%d, %d), (%d, %d))\n"

.text

# =======================================================================
# calc_blocks_needed
# Divides file size by 8 and calculates needed blocks.
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
    incl %eax           # Round up remainder

no_increment:
    popl %ebp
    ret


# =======================================================================
# allocate_blocks
# Maps a file descriptor directly into the matrix block interval.
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
# Finds free matrix blocks per row and adds the file contiguously.
# =======================================================================
add_file:
    pushl %ebp
    movl %esp, %ebp
    
    movl 12(%ebp), %eax
    movl %eax, file_size
    movl 8(%ebp), %eax
    movl %eax, file_desc

    # First, verify it doesn't already exist
    pushl file_desc
    call get_file
    popl %edx
    cmp $0, %ebx
    jne end_add

    # Calc blocks
    pushl file_size
    call calc_blocks_needed
    movl %eax, blocks_needed
    popl %ebx
    
    lea memory_array, %edi
    xorl %edx, %edx
    
    loop_add_rows:
        cmpl %edx, total_matrix_size
        je end_add
        
        # Prepare bounds for current row
        xorl %ecx, %ecx
        movl %edx, %ecx
        movl %edx, mem_limit
        movl %edx, temp_val1
        
        movl row_size, %edx
        addl %edx, mem_limit
        movl temp_val1, %edx
        
        loop_find_free:
            cmpl %ecx, mem_limit
            je next_add_row
            
            movl (%edi, %ecx, 4), %ebx
            cmpl $0, %ebx
            jne resume_find_free
            
            movl %ecx, %ebx
            movl %ecx, %eax
            addl blocks_needed, %ebx
            
            loop_check_contig:
                cmp %ecx, %ebx
                jne check_next_block
                
                # We can place file here
                pushl file_desc
                call allocate_blocks 
                popl %ecx
                popl %ebp
                dec %ebx
                ret

            check_next_block:
                cmp %ecx, mem_limit
                je next_add_row
                
                movl (%edi, %ecx, 4), %edx
                cmpl $0, %edx
                jne resume_find_free
                
                inc %ecx
                jmp loop_check_contig
            
            resume_find_free:
                inc %ecx
                jmp loop_find_free
                
        next_add_row:
            movl temp_val1, %edx
            addl row_size, %edx
            jmp loop_add_rows

    end_add:
    xorl %eax, %eax
    xorl %ebx, %ebx
    popl %ebp
    ret


# =======================================================================
# get_file
# Finds start/end coordinates of a descriptor stored in the 2D matrix.
# =======================================================================
get_file:
    pushl %ebp
    movl %esp, %ebp
    
    movl 8(%ebp), %ebx
    movl %ebx, file_desc
    lea memory_array, %edi
    xorl %edx, %edx
    
    loop_get_rows:
        cmpl %edx, total_matrix_size
        je end_get
        
        xorl %ecx, %ecx
        movl %edx, %ecx
        movl %edx, mem_limit
        movl %edx, temp_val1
        
        movl row_size, %edx
        addl %edx, mem_limit
        movl temp_val1, %edx
        
        loop_find_get:
            cmpl %ecx, mem_limit
            je next_get_row
            
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
                
        next_get_row:
            movl temp_val1, %edx
            addl row_size, %edx
            jmp loop_get_rows

    end_get:
    xorl %eax, %eax
    xorl %ebx, %ebx
    popl %ebp
    ret


# =======================================================================
# delete_file
# Finds file occurrences in the matrix and resets them to zero (0).
# =======================================================================
delete_file:
    pushl %ebp
    movl %esp, %ebp
    
    movl 8(%ebp), %ebx
    movl %ebx, file_desc
    lea memory_array, %edi
    xorl %ecx, %ecx
    xorl %edx, %edx
    
    loop_del_rows:
        cmpl %edx, total_matrix_size
        je end_del
        
        xorl %ecx, %ecx
        movl %edx, %ecx
        movl %edx, mem_limit
        movl %edx, temp_val1
        
        movl row_size, %edx
        addl %edx, mem_limit
        movl temp_val1, %edx
        
        loop_find_del:
            cmpl %ecx, mem_limit
            je next_del_row
            
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
                
        next_del_row:
            movl temp_val1, %edx
            addl row_size, %edx
            jmp loop_del_rows

    end_del:
    xorl %eax, %eax
    xorl %ebx, %ebx
    popl %ebp
    ret


# =======================================================================
# print_memory
# Scans matrix by rows, formats index to (row, col) coordinates.
# =======================================================================
print_memory:
    xorl %ecx, %ecx
    lea memory_array, %edi
    xorl %edx, %edx
    
    loop_print_rows:
        cmpl %edx, total_matrix_size
        je end_print
        
        xorl %ecx, %ecx
        movl %edx, %ecx
        movl %edx, mem_limit
        movl %edx, temp_val1
        movl row_size, %edx
        addl %edx, mem_limit
        movl temp_val1, %edx
        
        loop_print_mem:
            cmpl %ecx, mem_limit
            je next_print_row
            
            movl (%edi, %ecx, 4), %ebx
            cmpl $0, %ebx
            je resume_print_mem
            
            movl %ebx, file_desc
            movl %ecx, %eax
            
            loop_print_blocks:
                cmp %ecx, mem_limit
                jne check_print_end
                
                dec %ecx
                movl %ecx, %ebx
                movl %ecx, temp_val2
                
                # Calculate coordinates (Row = val/row_size, Col = val%row_size)
                movl %eax, %ecx
                xorl %edx, %edx
                movl %ebx, %eax
                divl row_size
                pushl %edx
                pushl %eax
                
                movl %ecx, %eax
                xorl %edx, %edx
                divl row_size
                pushl %edx
                pushl %eax
                pushl file_desc
                pushl $fmt_print_add
                call printf
                addl $24, %esp
                
                movl temp_val2, %ecx
                jmp next_print_row
                
            check_print_end:
                movl (%edi, %ecx, 4), %ebx
                cmp %ebx, file_desc
                je continue_print_blocks
                
                dec %ecx
                movl %ecx, start_idx
                movl %ecx, %ebx
                
                # Calculate coordinates
                movl %eax, %ecx
                xorl %edx, %edx
                movl %ebx, %eax
                divl row_size
                pushl %edx
                pushl %eax
                
                movl %ecx, %eax
                xorl %edx, %edx
                divl row_size
                pushl %edx
                pushl %eax
                pushl file_desc
                pushl $fmt_print_add
                call printf
                addl $24, %esp
                
                movl start_idx, %ecx
                jmp resume_print_mem
                
            continue_print_blocks:
                incl %ecx
                jmp loop_print_blocks

            resume_print_mem:
                incl %ecx
                jmp loop_print_mem
                
        next_print_row:
            movl temp_val1, %edx
            addl row_size, %edx
            jmp loop_print_rows

    end_print:
    xorl %eax, %eax
    xorl %ebx, %ebx
    ret


# =======================================================================
# add_defrag_file
# Custom helper used during defragmentation for matrix replacement.
# =======================================================================
add_defrag_file:
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
    xorl %edx, %edx
    
    movl curr_col, %ecx
    movl curr_col, %eax
    movl row_size, %ebx
    divl %ebx
    xorl %edx, %edx
    movl row_size, %ebx
    mull %ebx
    movl %eax, %edx
    
    loop_def_rows:
        cmpl %edx, total_matrix_size
        je end_add_def
        
        movl %edx, row_end_limit
        movl %edx, temp_val1
        movl row_size, %edx
        addl %edx, row_end_limit
        movl temp_val1, %edx
        
        loop_def_find_free:
            cmpl %ecx, row_end_limit
            je next_def_row
            
            movl (%edi, %ecx, 4), %ebx
            cmpl $0, %ebx
            jne resume_def_find_free
            
            movl %ecx, %ebx
            movl %ecx, %eax
            addl blocks_needed, %ebx

            loop_def_check_contig:
                cmp %ecx, %ebx
                jne check_next_def_block
                
                pushl file_desc
                call allocate_blocks
                popl %ebx
                movl %ecx, curr_col
                popl %ebp
                dec %ebx
                ret

            check_next_def_block:
                cmp %ecx, row_end_limit
                je next_def_row
                
                movl (%edi, %ecx, 4), %edx
                cmpl $0, %edx
                jne resume_def_find_free
                
                inc %ecx
                movl %ecx, curr_col
                jmp loop_def_check_contig
            
            resume_def_find_free:
                inc %ecx
                movl %ecx, curr_col
                jmp loop_def_find_free
                
        next_def_row:
            movl %ecx, curr_col
            movl temp_val1, %edx
            addl row_size, %edx
            xorl %ecx, %ecx
            movl %edx, %ecx
            movl %ecx, curr_col
            jmp loop_def_rows

    end_add_def:
    movl %ecx, curr_col
    xorl %eax, %eax
    xorl %ebx, %ebx
    popl %ebp
    ret


# =======================================================================
# defragment_memory
# Squashes fragmented gaps by shifting filled blocks upwards/leftwards.
# =======================================================================
defragment_memory:
    xorl %ecx, %ecx
    lea memory_array, %edi
    xorl %edx, %edx
    movl %edx, curr_col
    
    loop_defrag_rows:
        cmpl %edx, total_matrix_size
        je end_defrag
        
        xorl %ecx, %ecx
        movl %edx, %ecx
        movl %edx, mem_limit
        movl %edx, temp_def_val
        movl row_size, %edx
        addl %edx, mem_limit
        movl temp_def_val, %edx
        
        loop_find_defrag_blocks:
            cmpl %ecx, mem_limit
            je next_defrag_row
            
            movl (%edi, %ecx, 4), %ebx
            cmpl $0, %ebx
            je resume_find_defrag_blocks
            
            movl %ebx, file_desc
            movl %ecx, %eax
            
            loop_move_defrag_blocks:
                cmp %ecx, mem_limit
                jne check_def_bounds
                
                dec %ecx
                movl %ecx, %ebx
                movl %ecx, temp_val2
                
                # Re-calculate block math
                movl %ebx, %ecx
                subl %eax, %ebx
                movl %ebx, temp_val3
                addl temp_val3, %ebx
                addl temp_val3, %ebx
                addl temp_val3, %ebx
                addl temp_val3, %ebx
                addl temp_val3, %ebx
                addl temp_val3, %ebx
                addl temp_val3, %ebx
                addl $8, %ebx
                
                pushl %ebx
                pushl file_desc
                call add_defrag_file
                addl $8, %esp
                
                movl temp_val2, %ecx
                jmp next_defrag_row
                
            check_def_bounds:
                movl (%edi, %ecx, 4), %ebx
                cmp %ebx, file_desc
                je continue_def_move
                
                dec %ecx
                movl %ecx, start_idx
                movl %ecx, %ebx
                
            calc_defrag_coords:
                movl %ebx, %ecx
                subl %eax, %ebx
                movl %ebx, temp_val3
                
                # Math offset expansion (effectively multiply by 8 add 8)
                addl temp_val3, %ebx
                addl temp_val3, %ebx
                addl temp_val3, %ebx
                addl temp_val3, %ebx
                addl temp_val3, %ebx
                addl temp_val3, %ebx
                addl temp_val3, %ebx
                addl $8, %ebx
                
                pushl %ebx
                pushl file_desc
                call add_defrag_file
                addl $8, %esp
                
                movl start_idx, %ecx
                jmp resume_find_defrag_blocks
                
            continue_def_move:
                movl $0, (%edi, %ecx, 4)
                incl %ecx
                jmp loop_move_defrag_blocks

            resume_find_defrag_blocks:
                incl %ecx
                jmp loop_find_defrag_blocks
                
        next_defrag_row:
            movl temp_def_val, %edx
            addl row_size, %edx
            jmp loop_defrag_rows

    end_defrag:
    xorl %eax, %eax
    xorl %ebx, %ebx
    ret


# =======================================================================
# parse_file_name (for CONCRETE op)
# Isolates the numeric part of the file name logically.
# =======================================================================
parse_file_name:
    xorl %eax, %eax
    xorl %ebx, %ebx
    movl $10, %ebx
    
    loop_parse_chars:
        movl %eax, %edx
        xorl %eax, %eax
        movb (%esi, %ebx, 1), %al
        movl %eax, %ecx
        movl %edx, %eax
        cmp $0, %ecx
        je end_parse_name
        
        subl $48, %ecx
        cmp $0, %ecx
        jl continue_parse_chars
        cmp $9, %ecx
        jg continue_parse_chars
        
        xorl %edx, %edx
        movl $10, %edi
        mull %edi
        addl %ecx, %eax
        xorl %edx, %edx
        movl $255, %edi
        divl %edi
        movl %edx, %eax
        
    continue_parse_chars:
        incl %ebx
        jmp loop_parse_chars

    end_parse_name:
    inc %eax
    ret


# =======================================================================
# process_directory (for CONCRETE op)
# Iterates through directory files via kernel system calls.
# =======================================================================
process_directory:
    pushl %ebp
    movl %esp, %ebp
    pushl $0
    pushl $0
    
    # Int 0x80 SYS_OPEN (eax 5)
    movl $5, %eax
    movl 8(%ebp), %ebx
    xorl %ecx, %ecx
    int $0x80
    movl %eax, -4(%ebp)

    # Int 0x80 SYS_GETDENTS (eax 141) to read directory 
    movl %eax, %ebx
    movl $141, %eax
    movl $dir_data, %ecx
    movl $4096, %edx
    int $0x80

    cmpl $0, %eax
    jle end_process_dir
    
    movl $dir_data, %esi
    movl $0, total_bytes_read
    
    read_dir_entries:
        xorl %eax, %eax
        movl $8, %ebx

        movb (%esi, %ebx, 1), %al
        inc %ebx
        movb (%esi, %ebx, 1), %ah
        inc %ebx
        movl %eax, next_entry_offset
        cmpl $0, %eax
        je skip_dir_entry

        cmpb $46, (%esi, %ebx, 1)
        je skip_dir_entry
        
        xorl %edx, %edx
        movl $file_name, %edi
        movl $0x00, (%edi, %edx, 1)

        # Concatenate strings for path resolving
        pushl $folder_path
        pushl $file_name
        call strcat
        addl $8, %esp

        pushl $slash_str
        pushl $file_name
        call strcat
        addl $8, %esp
        
        movl %esi, %eax
        addl $10, %eax
        
        pushl %eax
        pushl $file_name
        call strcat
        addl $8, %esp
        
        # SYS_OPEN the nested file
        movl $5, %eax
        movl $file_name, %ebx
        xorl %ecx, %ecx
        int $0x80
        movl %eax, -8(%ebp)

        # SYS_FSTAT (eax 108) to retrieve file size
        movl %eax, %ebx
        movl $108, %eax
        movl $file_stats, %ecx
        int $0x80
        
        # Manually extract file size block
        movl $file_stats, %edi
        xorl %eax, %eax
        movl $22, %ecx
        movb (%edi, %ecx, 1), %al
        incl %ecx
        movb (%edi, %ecx, 1), %ah
        movl $20, %ecx
        shl $16, %eax
        movb (%edi, %ecx, 1), %al
        inc %ecx
        movb (%edi, %ecx, 1), %ah
        movl %eax, file_size
        
        # Descriptor calculation (val % 255 + 1)
        movl -8(%ebp), %eax
        movl $255, %ebx
        xorl %edx, %edx
        divl %ebx
        addl $1, %edx
        movl %edx, file_desc
        
        xorl %edx, %edx
        xorl %ebx, %ebx
        xorl %eax, %eax
        xorl %ecx, %ecx

        pushl file_desc
        pushl $dbg_fmt_int
        call printf
        addl $8, %esp
        
        # Check if already added
        pushl file_desc
        call get_file
        popl %edx

        cmp $0, %ebx
        je perform_add_entry
        
        movl file_size, %eax
        xorl %edx, %edx
        divl row_size
        xorl %edx, %edx
        movl %eax, file_size

        pushl %eax
        pushl $dbg_fmt_int
        call printf
        addl $8, %esp
        
        movl file_size, %eax
        pushl $0
        pushl $0
        pushl $0
        pushl $0
        pushl file_desc
        pushl $fmt_print_add
        call printf
        addl $24, %esp
        jmp skip_dir_entry

        perform_add_entry:
        # File is new, allocate it
        movl file_size, %eax
        xorl %edx, %edx
        divl row_size
        movl %eax, file_size

        pushl %eax
        pushl $dbg_fmt_int
        call printf
        addl $8, %esp
        
        movl file_size, %eax
        pushl file_size
        pushl file_desc
        call add_file
        addl $8, %esp
        
        # Calculate matrix points for print
        movl %eax, %ecx
        xorl %edx, %edx
        movl %ebx, %eax
        divl row_size
        pushl %edx
        pushl %eax
        
        movl %ecx, %eax
        xorl %edx, %edx
        divl row_size
        pushl %edx
        pushl %eax
        pushl file_desc
        pushl $fmt_print_add
        call printf
        addl $24, %esp

    skip_dir_entry:
        addl next_entry_offset, %esi
        movl next_entry_offset, %eax
        addl %eax, total_bytes_read
        cmp $0, %eax
        jne read_dir_entries

end_process_dir:
    # SYS_CLOSE the dir stream
    movl $6, %eax 
    movl -4(%ebp), %ebx
    int $0x80
    popl %edx
    popl %edx
    popl %ebp
    ret


# =======================================================================
# MAIN FUNCTION
# Parses the input file requests and routes execution path.
# =======================================================================
.global main

main:
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
            
            pushl $file_desc
            pushl $scan_fmt_int
            call scanf
            addl $8, %esp

            pushl $file_size
            pushl $scan_fmt_int
            call scanf
            addl $8, %esp

            pushl file_size
            pushl file_desc
            call add_file
            addl $8, %esp
            
            # Formatting matrix points
            movl %eax, %ecx
            xorl %edx, %edx
            movl %ebx, %eax
            divl row_size
            pushl %edx
            pushl %eax
            
            movl %ecx, %eax
            xorl %edx, %edx
            divl row_size
            pushl %edx
            pushl %eax
            pushl file_desc
            pushl $fmt_print_add
            call printf
            addl $24, %esp

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
        
        # Math calculation formatting
        movl %eax, %ecx
        xorl %edx, %edx
        movl %ebx, %eax
        divl row_size
        pushl %edx
        pushl %eax
        
        movl %ecx, %eax
        xorl %edx, %edx
        divl row_size
        pushl %edx
        pushl %eax
        pushl $fmt_print_get
        call printf
        addl $20, %esp
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
        jne check_op_concrete
        
        # --- OPERATION 4: DEFRAGMENT ---
        exec_defrag:
        call defragment_memory
        call print_memory
        jmp continue_loop_ops
        
    check_op_concrete:
        cmpl $5, op_code
        jne continue_loop_ops
        
        # --- OPERATION 5: CONCRETE ---
        xorl %ecx, %ecx
        movl $folder_path, %edi
        movl $0x00, (%edi, %ecx, 1)

        pushl $folder_path
        pushl $scan_fmt_str
        call scanf
        addl $8, %esp

        pushl $folder_path
        call process_directory 
        addl $4, %esp

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