SOLANA_SDK?=$(HOME)/.cache/solana/v1.41
LLVM_DIR?=$(SOLANA_SDK)/bpf-tools/llvm
CLANG:=$(LLVM_DIR)/bin/clang
LD:=$(LLVM_DIR)/bin/ld.lld

OBJDIR:=BUILD

ARCH_FLAGS:=-target bpf
ARCH_FLAGS+=-march=bpfel+solana

LDFLAGS:=
LDFLAGS+=-shared
LDFLAGS+=-z notext
LDFLAGS+=--image-base 0x100000000

CFLAGS:=
CFLAGS+=-Os
CFLAGS+=-xc
CFLAGS+=-std=c17
CFLAGS+=-fno-pic
CFLAGS+=-fno-builtin
CFLAGS+=-fvisibility=hidden

OBJS:=
OBJS+=$(OBJDIR)/TOKEN.O
OBJS+=$(OBJDIR)/TOKEN_EX.O

$(OBJDIR)/TOKEN.SO: $(OBJS) TOKEN.LD VERSION.SCRIPT
	$(LD) $(LDFLAGS) -T TOKEN.LD --version-script VERSION.SCRIPT -o $@ $(OBJS)

$(OBJDIR)/TOKEN_EX.O: TOKEN_EX.C
	mkdir -pv $(OBJDIR) && $(CLANG) $(ARCH_FLAGS) $(CFLAGS) -c -o $@ $<

$(OBJDIR)/TOKEN.O: TOKEN.S
	mkdir -pv $(OBJDIR) && $(CLANG) $(ARCH_FLAGS) -c -o $@ $<

.PHONY: clean
clean:
	rm -rv $(OBJDIR)
