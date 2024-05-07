#!/usr/bin/python3

TOKEN_ACCT_SIZE = 0x48
REALLOC_PAD = 10 * 1024

def align8(sz):
    sz += 7
    sz &= 0xFFFF_FFFF_FFFF_FFF8
    return sz

def main():
    cur = 0
    print(f"acct_cnt:              +{cur:#06x}"); cur +=  8
    print()
    print(f"acct[0].dup:           +{cur:#06x}"); cur +=  1
    print(f"acct[0].is_signer:     +{cur:#06x}"); cur +=  1
    print(f"acct[0].is_writable:   +{cur:#06x}"); cur +=  1
    print(f"acct[0].is_executable: +{cur:#06x}"); cur +=  1
    pass;                                         cur +=  4
    print(f"acct[0].pubkey:        +{cur:#06x}"); cur += 32
    print(f"acct[0].owner:         +{cur:#06x}"); cur += 32
    print(f"acct[0].lamports       +{cur:#06x}"); cur +=  8
    print(f"acct[0].data_sz        +{cur:#06x}"); cur +=  8
    print(f"acct[0].data           +{cur:#06x}"); cur += align8(TOKEN_ACCT_SIZE)
    pass;                                         cur += REALLOC_PAD
    print(f"acct[0].rent_epoch     +{cur:#06x}"); cur +=  8
    print()
    print(f"acct[1].dup:           +{cur:#06x}"); cur +=  1
    print(f"acct[1].is_signer:     +{cur:#06x}"); cur +=  1
    print(f"acct[1].is_writable:   +{cur:#06x}"); cur +=  1
    print(f"acct[1].is_executable: +{cur:#06x}"); cur +=  1
    pass;                                         cur +=  4
    print(f"acct[1].pubkey:        +{cur:#06x}"); cur += 32
    print(f"acct[1].owner:         +{cur:#06x}"); cur += 32
    print(f"acct[1].lamports       +{cur:#06x}"); cur +=  8
    print(f"acct[1].data_sz        +{cur:#06x}"); cur +=  8
    print(f"acct[1].data           +{cur:#06x}"); cur += align8(TOKEN_ACCT_SIZE)
    pass;                                         cur += REALLOC_PAD
    print(f"acct[2].rent_epoch     +{cur:#06x}"); cur +=  8
    print()
    print(f"acct[2].dup:           +{cur:#06x}"); cur +=  1
    print(f"acct[2].is_signer:     +{cur:#06x}"); cur +=  1
    print(f"acct[2].is_writable:   +{cur:#06x}"); cur +=  1
    print(f"acct[2].is_executable: +{cur:#06x}"); cur +=  1
    pass;                                         cur +=  4
    print(f"acct[2].pubkey:        +{cur:#06x}"); cur += 32
    print(f"acct[2].owner:         +{cur:#06x}"); cur += 32
    print(f"acct[2].lamports       +{cur:#06x}"); cur +=  8
    print(f"acct[2].data_sz        +{cur:#06x}"); cur +=  8
    print(f"acct[2].data           +{cur:#06x}"); cur +=  0
    pass;                                         cur += REALLOC_PAD
    pass;                                         cur +=  8
    print()
    print(f"min_instr_off          +{cur:#06x}");

if __name__ == "__main__":
    main()
