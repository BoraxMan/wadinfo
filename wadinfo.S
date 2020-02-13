# WADINFO: A assembly program which will display
# basic information about a Doom Engine WAD File.
#
# An example assembly program.  Does not use libc
# but relies solely on kernel syscalls.

# By Dennis Katsonis September 2015	
# Licence: Public Domain

.section .data

intro:
	.ascii "Wadinfo: By Dennis Katsonis, Sep 2015\n\n"
intro_len =  . - intro
	
iwad_id:
	.ascii "IWAD"
pwad_id:
	.ascii "PWAD"

file_error:
	.ascii "Can't open file.\n"
file_error_len = . - file_error

read_error:
	.ascii "Can't read file.\n"
read_error_len = . - read_error

notwad:
	.ascii "Not a wad.\n"
notwad_len = . - notwad

wadtype:
	.ascii "WAD Type : "
wadtypeoff = . - wadtype
	.ascii "XXXX\n"
wadtype_len = . - wadtype

lumpoffsetlabel:
	.ascii "Offset of directory : "
lumpoffsetlabel_len = . - lumpoffsetlabel

lumpname:
	.ascii "\nLump: "
lumpname_len = . - lumpname

numlumps_label:
	.ascii "Number of lumps : "
numlumps_label_len = . - numlumps_label
	
offset:
	.ascii "Offset: "
offset_len = . - offset
	
size_label:
	.ascii "Size: "
size_label_len = . - size_label

command_error:
	.ascii "wadinfo wadfile.wad\nOptions:	-s	Summary view\n"
command_error_len = . - command_error

	
	sys_read = 0x03
	sys_write = 0x04
	sys_lseek = 0x13
	sys_open = 0x05
	sys_brk = 0x2d
	lumpnamesize = 8
	
# BSS
.section .bss

	.lcomm wad_id, 4
	.lcomm ascifiedint, 32
	.lcomm ascifiedint_length, 4
	.lcomm summary, 4
	.lcomm numlumps, 4
	.lcomm lumpoffset, 4
	.lcomm filehandle, 4
	.lcomm lumpsize, 4
	.lcomm diroffset, 4
	.lcomm BRK_Start, 4
	.lcomm BRK_End, 4
	.lcomm filename_length, 4

# TEXT	
.section .text
.globl _start

_start:
	# Get current breakpoint
	mov %esp, %ebp
	movl $sys_brk, %eax
	xor %ebx, %ebx
	int $0x80
	movl %eax, BRK_Start
	movl %eax, BRK_End
	movl (%esp), %ecx
	cmp $1, %ecx
	je clifail
	cmp $3, %ecx
	jg clifail
	movl 8(%esp), %ebx
	jl success
	movb (%ebx), %al
	cmpb	$45,%al
	jne	clifail
	movb 1(%ebx), %al
	cmpb	$115,%al
	jne	clifail
	movl 12(%esp), %ebx
	movl $1, summary

success:
	cmpl $0, summary
	jg	skip4
	pushl %ebx
	movl $sys_write, %eax
	movl $1, %ebx
	movl $intro, %ecx
	movl $intro_len, %edx
	int $0x80
	popl %ebx
skip4:	
	movl $sys_open, %eax
	xor %ecx, %ecx
	xor %edx, %edx
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
	movl $sys_write, %eax
	movl $1, %ebx
	movl $notwad, %ecx
	movl $notwad_len, %edx
	int $0x80
	jmp end			
a_wad:
	movl $sys_read, %eax
	movl $4, %edx
	movl $numlumps, %ecx
	int $0x80
	test %eax, %eax
	js badread

	movl $sys_read, %eax
	movl $diroffset, %ecx
	movl $4, %edx
	int $0x80
	test %eax, %eax
	js badread


	movl $sys_lseek, %eax
	movl diroffset, %ecx
	xor %edx, %edx
	int $0x80 # Move the file pointer to the wad directory.

	pushl %ebx 		# Save file handle

	movl wad_id, %eax
	movl $wadtype, %edi
	movl %eax, wadtypeoff(%edi)

	cmpl $0, summary
	jg	skip1

	movl $sys_write, %eax
	movl $1, %ebx
	movl $wadtype, %ecx
	movl $wadtype_len, %edx
	int $0x80

	movl $sys_write, %eax
	movl $numlumps_label, %ecx
	movl $numlumps_label_len, %edx
	int $0x80

	movl numlumps, %eax
	call printAscifiedInt

	movl $sys_write, %eax
	movl $lumpoffsetlabel, %ecx
	movl $lumpoffsetlabel_len, %edx
	int $0x80
	movl diroffset, %eax
	call printAscifiedInt

	# Reserve memory
skip1:
	movl numlumps, %ebx
	shl $4, %ebx # Each entry is 16 bytes, so
	# multiply number of entries by 16 to get the
	# number of bytes we need to allocate.
	pushl %ebx	
	addl BRK_End, %ebx # Add to breakpoint
	movl $sys_brk, %eax
	int $0x80

 	movl $sys_read, %eax	# Read
	popl  %edx # Restore number of bytes 
	# allocated, as this is the number we will read.
	movl BRK_Start, %esi
	
	popl %ebx # And restore the file handle
	movl %esi, %ecx
	int $0x80
	# Now we have read the entire directory entry into the allocated memory
	movl numlumps, %ecx

lumpread_loop2:
	pushl %ecx

	cmpl $0, summary
	jg	skip5
	movl $sys_write, %eax
	movl $1, %ebx
 	movl $lumpname, %ecx
 	movl $lumpname_len, %edx
 	int $0x80
skip5:	
	call printlump
	cmpl $0, summary
	jg	skip3

	
	movl $sys_write, %eax
	movl $1, %ebx
	movl $offset, %ecx
	movl $offset_len, %edx
	int $0x80

	movl (%esi), %eax
	call printAscifiedInt

	movl $sys_write, %eax
	movl $1, %ebx
	movl $size_label, %ecx
	movl $size_label_len, %edx
	int $0x80

	movl 4(%esi), %eax
	call printAscifiedInt
skip3:	
	addl $16, %esi
	popl %ecx
	loop lumpread_loop2
end:
	movl $1, %eax
	movl $0, %ebx
	int $0x80

badfile:
	movl $sys_write, %eax
	movl $1, %ebx
	movl $file_error, %ecx
	movl $file_error_len, %edx
	int $0x80
	jmp end			

badread:
	movl $sys_write, %eax
	movl $1, %ebx
	movl $read_error, %ecx
	movl $read_error_len, %edx
	int $0x80
	jmp end			

clifail:
	
	movl $sys_write, %eax
	movl $1, %ebx
	movl $command_error, %ecx
	movl $command_error_len, %edx
	int $0x80
	movl $1, %eax
	movl $1, %ebx
	int $0x80

	
# FUNCTION : printAscifiedInt
	# The int is in %eax
	.type printAscifiedInt, @function
printAscifiedInt:
	leal ascifiedint+31, %edi
	movb $10, (%edi) # Trailing newline
	dec %edi
	movl $10, %ecx
	movl $2, ascifiedint_length
nextdigit:	
	xor %edx, %edx
	divl %ecx	# Divide the EDX:EAX pair by ECX
	orb $0x30, %dl  # Remainder in EDX, convert to ASCII
	# As we are dividing by 10, the remainder will always
	# fit in DL
	movb %dl, (%edi)
	cmpl $0, %eax	# No Quotent, so remainder was the final bit.
	jz enddigit
	dec %edi
	jmp nextdigit
enddigit:	
	movl $ascifiedint+32, %eax
	subl %edi, %eax
	movl %eax, ascifiedint_length

	movl $4, %eax
	movl $1, %ebx
	movl %edi, %ecx
	movl ascifiedint_length, %edx
	int $0x80
	ret

# FUNCTION : findnull
	# Based on a string pointed by EDI, return in EDX the location
	# of the NULL, otherwise return 8.
	.type findnull, @function
findnull:	
	movl $lumpnamesize, %ecx	# Length of LUMPNAME
	movl %ecx, %edx	# Set length to print to 8.
	# Anything shorter than 8 characters for a LUMPNAME
	# should be NULL terminated.
	# If null terminated, we do not print the NULL
	xor %eax, %eax	# Searching for NULL
	cld
	repne scasb
	jne notfound
	subl %ecx, %edx	# Subtract ECX value
	decl %edx	# and one more, because it stops one after it was found
notfound:	
	ret

#FUNCTION : printlump
	.type printlump, @function
printlump:	
	movl %esi, %edi
	add $lumpnamesize, %edi 	# Point EDI to start of LUMPNAME string
	call findnull
	movl $1, %ebx
	movl $sys_write, %eax
	movl %esi, %ecx
	add $lumpnamesize, %ecx
	int $0x80
	movl $lumpname, %ecx	# We only want the first character, a newline
	movl $1, %edx		# Just the first character, a newline
	movl $sys_write, %eax
	int $0x80
	ret
