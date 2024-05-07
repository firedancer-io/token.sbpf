# TOKEN.SBPF  version 0.99                                             #
# Simple token transfer program                                        #
#                                                                      #
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::#
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::#
#:  o         8                                 .oPYo.  .oPYo.  ooooo :#
#:  8         8                                 8   `8  8    8  8     :#
#: o8P .oPYo. 8  .o  .oPYo. odYo.       .oPYo. o8YooP' o8YooP' o8oo   :#
#:  8  8    8 8oP'   8oooo8 8' `8       Yb..    8   `b  8       8     :#
#:  8  8    8 8 `b.  8.     8   8  /--\   'Yb.  8    8  8       8     :#
#:  8  `YooP' 8  `o. `Yooo' 8   8  \--/ `YooP'  8oooP'  8       8     :#
#:::..::.....:..::...:.....:..::..::..:::.....::......::..::::::..:::::#
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::#
#                                                                      #
#                                                                      #
#   token.sBPF is a CU-minimized token program for Solana.             #
#   It is functionally comparable to Tokenkeg (signed minting,         #
#    permission-less transfers), but does not support freezing.        #
#                                                                      #
#   Notably, "express" token transfers cost only 56 CUs.               #
#                                                                      #
#                                                                      #
#----------------------------------------------------------------------#
#                                                                      #
#      token.sBPF is distributed WITHOUT WARRANTIES OF ANY KIND.       #
#     This code has not been audited.  Please assume it is broken.     #
#                                                                      #
#                  DO NOT DEPLOY THIS CODE ON MAINNET.                 #
#                                                                      #
#           For more information refer to the LICENSE file.            #
#                                                                      #
#----------------------------------------------------------------------#
#                                                                      #
# Build:                                                               #
#                                                                      #
#    Set $SOLANA_SDK to a Solana platform-tools installation           #
#    Run `make`                                                        #
#    The resulting program is at BUILD/TOKEN.SO                        #
#                                                                      #
# This program is compatible with BPF Loader v3 (sBPFv1).              #
#                                                                      #
# Usage:                                                               #
#                                                                      #
#   This program manages two kinds of accounts:                        #
#   A mint whose account address identifies the token.  The mint is    #
#   a required signatory when issuing new tokens.                      #
#   Token accounts which collectively hold the supply of a token.      #
#                                                                      #
# Instructions:                                                        #
#                                                                      #
#   Mint Tokens                                                        #
#   - Account 0:  Mint          ; signer writable sz=0x08              #
#   - Account 1:  Token account ;        writable sz=0x48              #
#   - Data (9 bytes):                                                  #
#     - u8  op_kind = 0                                                #
#     - u64 amount                                                     #
#                                                                      #
#   Set Authority / Set Mint                                           #
#   - Account 0:  Token account ;        writable sz=0x48              #
#   - Account 1:  Authority     ; signer                               #
#   - Data (33 bytes):                                                 #
#     - u8  op_kind = 1                                                #
#     - 32b new_authority                                              #
#   - Data (65 bytes):                                                 #
#     - u8  op_kind = 1                                                #
#     - 32b new_authority                                              #
#     - 32b mint_address                                               #
#                                                                      #
#   Transfer                                                           #
#   - Account 0:  Src token account ;        writable sz=0x48          #
#   - Account 1:  Dst token account ;        writable sz=0x48          #
#   - Account 2:  Authority of src  ; signer                           #
#   - Data (8 bytes):                                                  #
#     - u64 amount                                                     #
#   - Uses 56 CUs if all addresses are unique, token accounts are      #
#     initialized and same mint, authority is correct, and no          #
#     balance underflow or overflow.                                   #
#                                                                      #
# State:                                                               #
#                                                                      #
#   Mint (8 bytes)                                                     #
#   - u64 total_minted                                                 #
#                                                                      #
#   Token Account (72 bytes)                                           #
#   - 32b mint address                                                 #
#   - 32b token account address                                        #
#   - u64 balance                                                      #
#                                                                      #
#----------------------------------------------------------------------#

# Imports

.extern sol_log_
.extern entrypoint_ex

# Code

.section .text

#define TOKEN_ACCT_SZ 0x48

/* Various offsets derived using offsets.py */

#define INOFF_ACCT_CNT        0x0000

#define INOFF_ACCT0_HDR       0x0008
#define INOFF_ACCT0_SZ        0x0058
#define INOFF_ACCT0_MINT_Q0   0x0060
#define INOFF_ACCT0_MINT_Q1   0x0068
#define INOFF_ACCT0_MINT_Q2   0x0070
#define INOFF_ACCT0_MINT_Q3   0x0078
#define INOFF_ACCT0_AUTH_Q0   0x0080
#define INOFF_ACCT0_AUTH_Q1   0x0088
#define INOFF_ACCT0_AUTH_Q2   0x0090
#define INOFF_ACCT0_AUTH_Q3   0x0098
#define INOFF_ACCT0_BALANCE   0x00a0

#define INOFF_ACCT1_HDR       0x28b0
#define INOFF_ACCT1_SZ        0x2900
#define INOFF_ACCT1_MINT_Q0   0x2908
#define INOFF_ACCT1_MINT_Q1   0x2910
#define INOFF_ACCT1_MINT_Q2   0x2918
#define INOFF_ACCT1_MINT_Q3   0x2920
#define INOFF_ACCT1_AUTH_Q0   0x2928
#define INOFF_ACCT1_AUTH_Q1   0x2930
#define INOFF_ACCT1_AUTH_Q2   0x2938
#define INOFF_ACCT1_AUTH_Q3   0x2940
#define INOFF_ACCT1_BALANCE   0x2948

#define INOFF_ACCT2_HDR       0x5158
#define INOFF_ACCT2_ADDR_Q0   0x5160
#define INOFF_ACCT2_ADDR_Q1   0x5168
#define INOFF_ACCT2_ADDR_Q2   0x5170
#define INOFF_ACCT2_ADDR_Q3   0x5178

#define MIN_INSTR_DATA_OFF    0x79b8

.globl entrypoint
entrypoint:
    # check: account_cnt == 3

    r3 = *(u64 *)(r1 + INOFF_ACCT_CNT)                           #  1 CU
    if r3 != 3 goto beach                                        #  2 CU

    # check: account[0].duplicate_index == 0xFF &&
    #        account[0].is_signer       == 0x01 &&
    #        account[0].is_writable     == 0x01 &&
    #        account[0].is_executable   == 0x00

    r3 = *(u32 *)(r1 + INOFF_ACCT0_HDR)                          #  3 CU
    r3 &= 0xFF00FF                                               #  4 CU
    if r3 != 0x0100FF goto beach                                 #  5 CU

    # check: account[0].size == TOKEN_ACCT_SZ

    r3 = *(u64 *)(r1 + INOFF_ACCT0_SZ)                           #  6 CU
    if r3 != TOKEN_ACCT_SZ goto beach                            #  7 CU

    # check: account[1].duplicate_index == 0xFF &&
    #        account[1].is_writable     == 0x01 &&
    #        account[1].is_executable   == 0x00
    #
    # Since the account is writable omit the owner check (dangerous!)

    r3  = *(u32 *)(r1 + INOFF_ACCT1_HDR)                         #  8 CU
    r3 &= 0xFF00FF                                               #  9 CU
    if r3 != 0x0100FF goto beach                                 # 10 CU

    # check: account[1].size == TOKEN_ACCT_SZ

    r3 = *(u64 *)(r1 + INOFF_ACCT1_SZ)                           # 11 CU
    if r3 != TOKEN_ACCT_SZ goto beach                            # 12 CU

    # check: account[2].duplicate_index == 0xFF &&
    #        account[2].is_signer       == 0x01

    r3 = *(u16 *)(r1 + INOFF_ACCT2_HDR)                          # 13 CU
    if r3 != 0x01FF goto beach                                   # 14 CU

    # check: account[0].data.mint == account[1].data.mint

    r4 = *(u64 *)(r1 + INOFF_ACCT0_MINT_Q0)                      # 15 CU
    r5 = *(u64 *)(r1 + INOFF_ACCT0_MINT_Q1)                      # 16 CU
    r6 = *(u64 *)(r1 + INOFF_ACCT1_MINT_Q0)                      # 17 CU
    r7 = *(u64 *)(r1 + INOFF_ACCT1_MINT_Q1)                      # 18 CU
    if r4 != r6 goto beach                                       # 19 CU
    if r5 != r7 goto beach                                       # 20 CU
    r4 = *(u64 *)(r1 + INOFF_ACCT0_MINT_Q2)                      # 21 CU
    r5 = *(u64 *)(r1 + INOFF_ACCT0_MINT_Q3)                      # 22 CU
    r6 = *(u64 *)(r1 + INOFF_ACCT1_MINT_Q2)                      # 23 CU
    r7 = *(u64 *)(r1 + INOFF_ACCT1_MINT_Q3)                      # 24 CU
    if r4 != r6 goto beach                                       # 25 CU
    if r5 != r7 goto beach                                       # 26 CU

    # check: account[0].data.authority == account[2].pubkey

    r4 = *(u64 *)(r1 + INOFF_ACCT0_AUTH_Q0)                      # 27 CU
    r5 = *(u64 *)(r1 + INOFF_ACCT0_AUTH_Q1)                      # 28 CU
    r6 = *(u64 *)(r1 + INOFF_ACCT2_ADDR_Q0)                      # 29 CU
    r7 = *(u64 *)(r1 + INOFF_ACCT2_ADDR_Q1)                      # 30 CU
    if r4 != r6 goto beach                                       # 31 CU
    if r5 != r7 goto beach                                       # 32 CU
    r4 = *(u64 *)(r1 + INOFF_ACCT0_AUTH_Q2)                      # 33 CU
    r5 = *(u64 *)(r1 + INOFF_ACCT0_AUTH_Q3)                      # 34 CU
    r6 = *(u64 *)(r1 + INOFF_ACCT2_ADDR_Q2)                      # 35 CU
    r7 = *(u64 *)(r1 + INOFF_ACCT2_ADDR_Q3)                      # 36 CU
    if r4 != r6 goto beach                                       # 37 CU
    if r5 != r7 goto beach                                       # 38 CU

    # r3 <- align_up( account[2].size, 8 )

    r3  = *(u64 *)(r1 + 0x5198)                                  # 39 CU
    r3 +=  7                                                     # 40 CU
    r3 &= -8                                                     # 41 CU

    # r3 <- &instr.data

    r3 += r1                                                     # 42 CU
    r3 += MIN_INSTR_DATA_OFF                                     # 43 CU

    # check: instr.data_sz == 0x08

    r2 = *(u64 *)(r3 + 0x00)                                     # 44 CU
    if r2 != 0x08 goto beach                                     # 45 CU

    # r2 <- instr.data.amount
    # r3 <- account[0].data.balance
    # r4 <- account[1].data.balance

    r2 = *(u64 *)(r3 + 0x08)                                     # 46 CU
    r3 = *(u64 *)(r1 + INOFF_ACCT0_BALANCE)                      # 47 CU
    r4 = *(u64 *)(r1 + INOFF_ACCT1_BALANCE)                      # 48 CU

    # check: instr.data.amount <= account[0].data.balance

    if r2 > r3 goto insufficient_balance                         # 49 CU

    # account[0].data.balance -= instr.data.amount

    r3 -= r2                                                     # 50 CU
    *(u64 *)(r1 + INOFF_ACCT0_BALANCE) = r3                      # 51 CU

    # check: account[1].data.balance + instr.data.amount < 2^64
    # account[1].data.balance += instr.data.amount

    r5 = r4                                                      # 52 CU
    r5 += r2                                                     # 53 CU
    if r5 < r4 goto overflow                                     # 54 CU
    *(u64 *)(r1 + INOFF_ACCT1_BALANCE) = r5                      # 55 CU

    # Token transfer complete

    exit                                                         # 56 CU

insufficient_balance:
    r1 = str_insufficient_balance ll
    r2 = 20
    call sol_log_
    r0 = 2
    exit

overflow:
    r1 = str_overflow ll
    r2 = 9
    call sol_log
    r0 = 3
    exit

# Trampoline to slow path

beach:
    r1 = 0x400000000 ll
    call entrypoint_ex
    exit


#----------------------------------------------------------------------#
# Note on known issues:                                                #
#                                                                      #
#   - The mint ID is 32 bytes but could be shortened to 8 bytes by     #
#     using PDAs for mint addresses.   This would save approx 11 CU    #
#     for transfers.                                                   #
#                                                                      #
#   - The program does not check whether provided accounts are owned   #
#     by itself.  Instead it checks whether an account is writable.    #
#     This may be safe for now but could be exploitable (infinite      #
#     mint bug) if network allows programs to write to accounts other  #
#     than itself in the future.                                       #
#                                                                      #
#   - No support for closing accounts yet.                             #
#                                                                      #
#   - Incomplete tests.                                                #
#                                                                      #
#----------------------------------------------------------------------#

