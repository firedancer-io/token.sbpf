typedef unsigned char  uchar;
typedef   signed char  schar;
typedef unsigned short ushort;
typedef unsigned int   uint;
typedef unsigned long  ulong;

char const str_mint_mismatch[]        = "MINT_MISMATCH";
char const str_insufficient_balance[] = "INSUFFICIENT_BALANCE";
char const str_unauthorized[]         = "UNAUTHORIZED";
char const str_overflow[]             = "OVERFLOW";

#define ERR_ARG          (1)
#define ERR_UNAUTHORIZED (2)

extern ulong
sol_log_( char const * str, ulong len );

__attribute__((pure)) static inline ulong
eq32( uchar const a[32],
      uchar const b[32] ) {
  ulong const * a_ = (ulong const *)a;
  ulong const * b_ = (ulong const *)b;
  return (a_[0] == b_[0]) & (a_[1] == b_[1]) & (a_[2] == b_[2]) & (a_[3] == b_[3]);
}

__attribute__((pure)) static inline ulong
eq32_0( uchar const a[32] ) {
  ulong const * a_ = (ulong const *)a;
  return (a_[0] == 0) & (a_[1] == 0) & (a_[2] == 0) & (a_[3] == 0);
}

static inline void
cpy32( uchar       dst[32],
       uchar const src[32] ) {
  ulong const * src_ = (ulong const *)src;
  ulong       * dst_ = (ulong       *)dst;
  dst_[0] = src_[0];
  dst_[1] = src_[1];
  dst_[2] = src_[2];
  dst_[3] = src_[3];
}

union __attribute__((packed)) sol_acct {

  uchar dup_idx;

  struct __attribute__((packed)) {
    uchar dup_marker;
    uchar is_signer;
    uchar is_writable;
    uchar is_executable;
    uint  pad;
    uchar pubkey[32];
    uchar owner [32];
    ulong lamports;
    ulong data_sz;
    uchar data[0];
  };

};

typedef union sol_acct sol_acct_t;

__attribute__((const)) static inline ulong
sol_acct_footprint( sol_acct_t const * acct ) {
  return sizeof(sol_acct_t) + ((acct->data_sz + 10*1024 + 8 + 7) & ~7);
}

struct __attribute__((packed)) token_acct {
  uchar mint[32];
  uchar authority[32];
  ulong balance;
};

typedef struct token_acct token_acct_t;

static ulong
transfer( sol_acct_t * src,
          sol_acct_t * dst,
          sol_acct_t * authority,
          ulong        lamports ) {

  if( src == dst                           ) return 1;

  if( !src->is_writable                    ) return 1;
  if( src->data_sz != sizeof(token_acct_t) ) return 1;

  if( !dst->is_writable                    ) return 1;
  if( dst->data_sz != sizeof(token_acct_t) ) return 1;

  if( !authority                           ) return 1;
  if( !authority->is_signer                ) return 1;

  token_acct_t * src_token = (token_acct_t *)src->data;
  token_acct_t * dst_token = (token_acct_t *)dst->data;

  if( !eq32( src_token->authority, authority->pubkey ) ) {
    sol_log_( str_unauthorized, 12UL );
    return ERR_UNAUTHORIZED;
  }

  if( src_token->balance < lamports ) {
    sol_log_( str_insufficient_balance, 20UL );
    return 3UL;
  }

  ulong prev_src_bal = src_token->balance;
  ulong prev_dst_bal = dst_token->balance;

  ulong post_src_bal = prev_src_bal - lamports;
  ulong post_dst_bal = prev_dst_bal + lamports;

  if( post_dst_bal < prev_dst_bal ) {
    sol_log_( str_overflow, 8UL );
    return 4UL;
  }

  src_token->balance = post_src_bal;
  dst_token->balance = post_dst_bal;
  return 0UL;
}

static ulong
mint( sol_acct_t * mint,
      sol_acct_t * acct,
      uchar const  data[9] ) {

  if( !mint->is_signer                      ) return 1;
  if( !mint->is_writable                    ) return 1;
  if( mint->data_sz != 0x08                 ) return 1;

  if( !acct->is_writable                    ) return 1;
  if( acct->data_sz != sizeof(token_acct_t) ) return 1;

  ulong prev_minted = *(ulong *)(mint->data);
  ulong amount      = *(ulong *)(data + 1);
  ulong post_minted = prev_minted + amount;

  if( post_minted < prev_minted ) {
    sol_log_( str_overflow, 8UL );
    return 3UL;
  }

  token_acct_t * token = (token_acct_t *)acct->data;
  if( !eq32( token->mint, mint->pubkey ) ) {
    sol_log_( str_mint_mismatch, 13UL );
    return 1UL;
  }

  ulong prev_balance = token->balance;
  ulong post_balance = prev_balance + amount;

  if( post_balance < prev_balance ) {
    sol_log_( str_overflow, 8UL );
    return 4UL;
  }

  *(ulong *)(mint->data) = post_minted;
  token->balance         = post_balance;
  return 0UL;
}

static ulong
initialize( sol_acct_t *  acct,
            sol_acct_t *  authority,
            uchar const * data,
            ulong         data_sz ) {

  if( !acct->is_writable                    ) return 1;
  if( acct->data_sz != sizeof(token_acct_t) ) return 1;

  if( !authority->is_signer ) return 1;

  token_acct_t * token = (token_acct_t *)acct->data;

  switch( data_sz ) {

  case 65:  /* set authority and mint */ {

    if( !eq32_0( token->mint ) ) {
      /* mint already set */
      sol_log_( str_unauthorized, 12UL );
      return ERR_UNAUTHORIZED;
    }

    cpy32( token->mint, data + 1 );

    __attribute__((fallthrough));
  }

  case 33:  /* set authority */ {

    uchar * current_authority;
    if( eq32_0( token->authority ) ) {
      current_authority = acct->pubkey;
    } else {
      current_authority = token->authority;
    }

    if( !eq32( current_authority, authority->pubkey ) ) {
      sol_log_( str_unauthorized, 12UL );
      return ERR_UNAUTHORIZED;
    }

    cpy32( token->authority, data + 1 );

    return 0;
  }

  default:
    return 1;
  }
}

ulong
entrypoint_ex( uchar * const base ) {
  uchar * cur = base;

  ulong acct_cnt = *(ulong *)cur;
  cur += sizeof(ulong);
  if( acct_cnt < 2 ) return 1;

  sol_acct_t * acct[3];

  acct[0] = (sol_acct_t *)cur;
  cur += sol_acct_footprint( acct[0] );

  acct[1] = (sol_acct_t *)cur;
  if( acct[1]->dup_idx == 0xFF ) {
    cur += sol_acct_footprint( acct[1] );
  } else {
    acct[1] = acct[0];
    cur += 8;
  }

  if( acct_cnt > 2 ) {
    if( acct_cnt != 3 ) return 1;
    acct[2] = (sol_acct_t *)cur;
    if( acct[2]->dup_idx == 0xFF ) {
      cur += sol_acct_footprint( acct[2] );
    } else {
      acct[2] = acct[ acct[2]->dup_idx ];
      cur += 8;
    }
  } else {
    acct[2] = 0;
  }

  ulong data_sz = *(ulong *)cur;
  cur += sizeof(ulong);
  uchar const * data = cur;

  if( data_sz == 8 ) {
    if( !acct[2] ) return 1;
    return transfer( acct[0], acct[1], acct[2], *(ulong *)data );
  }

  if( data_sz < 9 ) return 1;

  if( *data == 0 ) {
    return mint( acct[0], acct[1], data );
  } else if( *data == 1 ) {
    return initialize( acct[0], acct[1], data, data_sz );
  }

  /* Unknown instruction */
  return 1;
}
