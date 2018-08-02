# WADINFO: A assembly program which will display
# basic information about a Doom Engine WAD File.
#
# An example assembly program.  Does not use libc
# but relies solely on kernel syscalls.

# By Dennis Katsonis September 2015	
# Licence: Public Domain

	.section .data

numlumps:
	.int 0
lumpoffset:
	.int 0
filehandle:
	.int 0
lumpsize:
	.int 0
diroffset:
	.int 0
BRK_Start:
	.int 0
BRK_End:
	.int 0

filename_length:
	.int 0
intro:
	.ascii "Wadinfo: By Dennis Katsonis September 2015\n\n"
intro_end:
	.equ intro_len, intro_end - intro
iwad_id:
	.ascii "IWAD"
pwad_id:
	.ascii "PWAD"
wadfile:	
	.asciz "test.wad"
wadfile_end:	
	.equ wadfile_len, wadfile_end - wadfile
file_error:
	.ascii "Could not open file "
file_error_end:
	.equ file_error_len, file_error_end - file_error

read_error:
	.ascii "Could not read file.\n"
read_error_end:
	.equ read_error_len, read_error_end - read_error

notwad:
	.ascii "Not a wad file.\n"
notwad_end:
	.equ notwad_len, notwad_end - notwad
wadtype:
	.ascii "Type of WAD file is XXXX\n"
wadtype_end:
	.equ wadtype_len, wadtype_end - wadtype

lumpoffsetlabel:
	.ascii "Byte offset in WAD file of the start of the directory is "
lumpoffsetlabel_end:
	.equ lumpoffsetlabel_len, lumpoffsetlabel_end - lumpoffsetlabel

lumpname:
	.ascii "\nLump: "
lumpname_end:
	.equ lumpname_len, lumpname_end - lumpname

numlumps_label:
	.ascii "The number of lumps is "
numlumps_label_end:
	.equ numlumps_label_len, numlumps_label_end - numlumps_label
	
offset:
	.ascii "\nOffset: "
offset_end:
	.equ offset_len, offset_end - offset
size_label:
	.ascii "Size: "
size_label_end:
	.equ size_label_len, size_label_end - size_label

command_error:
	.ascii "How to use:\nwadinfo wadfile.wad\n"
command_error_end:
	.equ command_error_len, command_error_end - command_error

# BSS
	.section .bss

	.lcomm wad_id, 4
	.lcomm ascifiedint, 18

# TEXT	
	.section .text
	.globl _start
_start:
	# Get current breakpoint
	
	movl $45, %eax
	xor %ebx, %ebx
	int $0x80
	movl %eax, BRK_Start
	movl %eax, BRK_End
	

	movl $4, %eax
	movl $1, %ebx
	movl $intro, %ecx
	movl $intro_len, %edx
	int $0x80
                         
	movl (%esp), %ecx
	cmp $2, %ecx
	je success
	movl $4, %eax
	movl $1, %ebx
	movl $command_error, %ecx
	movl $command_error_len, %edx
	int $0x80
	movl $1, %eax
	movl $1, %ebx
	int $0x80
	
success:	
	movl %esp, %ebp
	addl $8, %ebp
	movl (%ebp), %edi
	
	sub %ecx, %ecx
	not %ecx
	sub %al, %al
	cld
	repne scasb
	not %ecx
	dec %ecx

	movl %ecx, %edx
	movl %ecx, filename_length
	
	movl $5, %eax
	movl (%ebp), %ebx
	movl $0, %ecx
	movl $0644, %edx
	int $0x80
	test %eax, %eax
	js badfile
	movl %eax, filehandle
	# Now try to read data

	movl $3, %eax
	
	movl %eax, %ebx # %eax already has filehandle
	movl $wad_id, %ecx
	movl $4, %edx
	int $0x80
	test %eax, %eax
	js badread

	# See if wadfile

	leal iwad_id, %esi
	leal wad_id, %edi
	pushl %edi # Preserve as it will be changed.
	cld
	cmpsl
	je a_wad 
	leal pwad_id, %esi #See if pwad
	popl %edi # Get original edi which points to wad_id
	cmpsl
	je a_wad

not_a_wad:
	movl $4, %eax
	movl $1, %ebx
	movl $notwad, %ecx
	movl $notwad_len, %edx
	int $0x80
	jmp end			

a_wad:	
	movl $3, %eax
	movl $4, %edx
	movl $numlumps, %ecx
	int $0x80
	test %eax, %eax
	js badread

	movl $3, %eax
	movl $diroffset, %ecx
	movl $4, %edx
	int $0x80
	test %eax, %eax
	js badread

	movl $0x13, %eax
	movl diroffset, %ecx
	movl $0, %edx
	int $0x80 # Move the file pointer to the wad directory.

	pushl %ebx

	movl wad_id, %eax
	movl $wadtype, %edi
	movl %eax, 20(%edi)
	
	movl $4, %eax
	movl $1, %ebx
	movl $wadtype, %ecx
	movl $wadtype_len, %edx
	int $0x80

	movl $4, %eax
	movl $numlumps_label, %ecx
	movl $numlumps_label_len, %edx
	int $0x80

	movl numlumps, %eax
	call int2ascii
	call printAscifiedInt

	movl $4, %eax
	movl $lumpoffsetlabel, %ecx
	movl $lumpoffsetlabel_len, %edx
	int $0x80

	movl diroffset, %eax
	call int2ascii
	call printAscifiedInt


	# Reserve memory
	
	
	movl numlumps, %ebx
	shl $4, %ebx # Each entry is 16 bytes, so
	# multiply number of entries by 16 to get the
	# number of bytes we need to allocate.
	pushl %ebx
	addl BRK_End, %ebx # Add to breakpoint
	movl $45, %eax
	int $0x80

 	movl $3, %eax	# Read
	popl  %edx # Restore number of bytes
	# allocated, as this is the number we will read.
	xor %esi, %esi
	movl BRK_Start, %esi
	
	popl %ebx # And restore the file handle
	movl %esi, %ecx
	int $0x80
	# Now we've read the entire directory entry into the allocated memory


	movl numlumps, %ecx
	

lumpread_loop2:
	pushl %ecx
	movl $4, %eax
	movl $1, %ebx
	movl $offset, %ecx
	movl $offset_len, %edx
	int $0x80

	movl (%esi), %eax
	call int2ascii
	call printAscifiedInt

	addl $4, %esi
	movl $4, %eax
	movl $1, %ebx
	movl $size_label, %ecx
	movl $size_label_len, %edx
	int $0x80

	movl (%esi), %eax
	call int2ascii
	call printAscifiedInt

	addl $4, %esi
	movl $4, %eax
	movl $1, %ebx
 
 	movl $lumpname, %ecx
 	movl $lumpname_len, %edx
 	int $0x80
	
	movl $4, %eax
	movl $1, %ebx
	movl %esi, %ecx
	movl $8, %edx
	int $0x80
	addl $8, %esi
	popl %ecx
	loop lumpread_loop2
	jmp end
	
	movl $4, %eax
	movl $lumpname, %ecx
	movl $lumpname_len, %edx
	int $0x80

	movl lumpoffset, %eax
	movl lumpsize, %eax
	call int2ascii
	call printAscifiedInt
	
	popl %ebx
	popl %ecx
	loop lumpread_loop
	movl numlumps, %ecx
	popl %ebx

lumpread_loop:
	pushl %ecx
	movl $3, %eax

	call readLumpInfo
	test %eax, %eax
	js badread

	pushl %ebx
	movl $4, %eax
	movl $1, %ebx
	movl $lumpname, %ecx
	movl $lumpname_len, %edx
	int $0x80

	movl $4, %eax
	movl $offset, %ecx
	movl $offset_len, %edx
	int $0x80

	movl lumpoffset, %eax
	call int2ascii
	call printAscifiedInt

	movl $4, %eax
	movl $1, %ebx
	movl $size_label, %ecx
	movl $size_label_len, %edx
	int $0x80

	movl lumpsize, %eax
	call int2ascii
	call printAscifiedInt
	
	popl %ebx
	popl %ecx
	loop lumpread_loop

end:
	movl lumpoffset, %eax
	call int2ascii
	movl %edx, %ebx
	movl $1, %eax
#	movl $0, %ebx
	int $0x80

badfile:
	movl $4, %eax
	movl $1, %ebx
	movl $file_error, %ecx
	movl $file_error_len, %edx
	int $0x80
	movl $4, %eax
	movl (%ebp), %ecx
	movl filename_length, %edx
	int $0x80
	jmp end			

badread:
	movl $4, %eax
	movl $1, %ebx
	movl $read_error, %ecx
	movl $read_error_len, %edx
	int $0x80
	jmp end			


# FUNCTION : readLumpInfo
	
	.type readLumpInfo, @function
readLumpInfo:
	# This requires the filehandle in %ebx
	# Status is returned in %eax
	
	movl $lumpoffset, %ecx
	movl $4, %edx
	int $0x80
	
 	movl $3, %eax
	movl $lumpsize, %ecx
	movl $4, %edx
	int $0x80
	
	movl $3, %eax
	movl $lumpname+7, %ecx
	movl $8, %edx
	int $0x80
	ret


# FUNCTION : printAscifiedInt
	.type printAscifiedInt, @function
printAscifiedInt:
	movl $4, %eax
	movl $1, %ebx
	movl $ascifiedint, %ecx
	leal ascifiedint+12, %edi
	movl (%edi), %edx
	int $0x80
	ret


# FUNCTION : int2ascii
	.type int2ascii, @function
int2ascii:
	# The int is in %eax
	pushl %esi
	leal ascifiedint+9, %edi
	xor %ebx, %ebx
	movl $10, %ecx
nextdigit:	
	xor %edx, %edx
	divl %ecx
	inc %ebx
	addb $0x30, %dl
	movb %dl, (%edi)
	inc %edi
	cmpl $0, %eax
	jnz nextdigit
	movl %ebx, %ecx
	
	# We have the string, now reverse it.
	leal ascifiedint, %edi
	leal ascifiedint+8, %esi
	add %ecx, %esi
nextdigit_2:
	movb (%esi), %al
	movb %al, (%edi)
	dec %esi
	inc %edi
	loop nextdigit_2
	movb $'\n', (%edi)
	inc %ebx
	leal ascifiedint+12, %edi
	movl %ebx, (%edi)
	popl %esi
	ret
