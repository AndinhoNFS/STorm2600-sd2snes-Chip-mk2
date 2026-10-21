# SPDX-License-Identifier: GPL-2.0-or-later
.DEFAULT_GOAL := all
# Corner-case test ROMs of the TIA (Step 33).  Needs cc65 (ca65 and ld65).  `make` builds all of them into ./rom/.
CA65 ?= ca65
LD65 ?= ld65
SRC  = resp_hblank resp_midline nusiz_mid d2_resm resm_wrap hmove_m0
RESM_VARIANTS = w1:0 w2:16 w4:32 w8:48 w1_n3:3
RESM_NAMES = $(foreach v,$(RESM_VARIANTS),$(word 1,$(subst :, ,$(v))))
ROMS = $(addprefix rom/,$(addsuffix .a26,$(SRC))) rom/resp_double_n0.a26 rom/resp_double_n3.a26 \
       $(foreach n,$(RESM_NAMES),rom/resm_$(n)_a.a26 rom/resm_$(n)_b.a26)

rom/%.a26: %.s tia_test.inc tia4k.cfg
	@mkdir -p rom
	$(CA65) -o rom/$*.o $<
	$(LD65) -C tia4k.cfg -o $@ rom/$*.o

rom/resp_double_n0.a26: resp_double.s tia_test.inc tia4k.cfg
	@mkdir -p rom; $(CA65) -D NUS=0 -o rom/rd0.o $<; $(LD65) -C tia4k.cfg -o $@ rom/rd0.o
rom/resp_double_n3.a26: resp_double.s tia_test.inc tia4k.cfg
	@mkdir -p rom; $(CA65) -D NUS=3 -o rom/rd3.o $<; $(LD65) -C tia4k.cfg -o $@ rom/rd3.o

define RESM_RULE
rom/resm_$(1)_a.a26: resm_basic.s tia_test.inc tia4k.cfg
	@mkdir -p rom; $(CA65) -D NUS=$(2) -D CBASE=2 -o rom/m$(1)a.o $$<; $(LD65) -C tia4k.cfg -o $$@ rom/m$(1)a.o
rom/resm_$(1)_b.a26: resm_basic.s tia_test.inc tia4k.cfg
	@mkdir -p rom; $(CA65) -D NUS=$(2) -D CBASE=38 -o rom/m$(1)b.o $$<; $(LD65) -C tia4k.cfg -o $$@ rom/m$(1)b.o
endef
$(foreach v,$(RESM_VARIANTS),$(eval $(call RESM_RULE,$(word 1,$(subst :, ,$(v))),$(word 2,$(subst :, ,$(v))))))

# res_basic.s: M1, ball, P0, P1 over the line (OBJ 1 = M1, 2 = BL, 3 = P0, 4 = P1)
RB = m1_n0:1:0 m1_n3:1:3 bl_w1:2:0 bl_w2:2:16 bl_w4:2:32 bl_w8:2:48 p0_n0:3:0 p0_n1:3:1 p0_n2:3:2 p0_n3:3:3 p0_n4:3:4 p0_n5:3:5 p0_n6:3:6 p0_n7:3:7 p1_n0:4:0 p1_n6:4:6
define RB_RULE
rom/res_$(1)_a.a26: res_basic.s tia_test.inc tia4k.cfg
	@mkdir -p rom; $(CA65) -D OBJ=$(2) -D NUS=$(3) -D CBASE=2 -o rom/rb$(1)a.o $$<; $(LD65) -C tia4k.cfg -o $$@ rom/rb$(1)a.o
rom/res_$(1)_b.a26: res_basic.s tia_test.inc tia4k.cfg
	@mkdir -p rom; $(CA65) -D OBJ=$(2) -D NUS=$(3) -D CBASE=38 -o rom/rb$(1)b.o $$<; $(LD65) -C tia4k.cfg -o $$@ rom/rb$(1)b.o
endef
$(foreach v,$(RB),$(eval $(call RB_RULE,$(word 1,$(subst :, ,$(v))),$(word 2,$(subst :, ,$(v))),$(word 3,$(subst :, ,$(v))))))
ROMS += $(foreach v,$(RB),rom/res_$(word 1,$(subst :, ,$(v)))_a.a26 rom/res_$(word 1,$(subst :, ,$(v)))_b.a26)

# hmove_obj.s: HMOVE on cycles 4..74 with P0 (hmove_late, OBJ 3), M1 (OBJ 1) and the ball (OBJ 2); the object is placed again before every test
define HO_RULE
rom/$(1).a26: hmove_obj.s tia_test.inc tia4k.cfg
	@mkdir -p rom; $(CA65) -D OBJ=$(2) -o rom/$(1).o $$<; $(LD65) -C tia4k.cfg -o $$@ rom/$(1).o
endef
$(eval $(call HO_RULE,hmove_late,3))
$(eval $(call HO_RULE,hmove_m1,1))
$(eval $(call HO_RULE,hmove_bl,2))
$(eval $(call HO_RULE,hmove_p0d,4))
$(eval $(call HO_RULE,hmove_p0q,5))
$(eval $(call HO_RULE,hmove_p0c,6))
ROMS += rom/hmove_late.a26 rom/hmove_m1.a26 rom/hmove_bl.a26 rom/hmove_p0d.a26 rom/hmove_p0q.a26 rom/hmove_p0c.a26

# resp_hm.s: RESxx inside the HBLANK extended by an HMOVE at the start of the line (P0, M0, ball)
define RH_RULE
rom/$(1).a26: resp_hm.s tia_test.inc tia4k.cfg
	@mkdir -p rom; $(CA65) -D OBJ=$(2) -o rom/$(1).o $$<; $(LD65) -C tia4k.cfg -o $$@ rom/$(1).o
endef
$(eval $(call RH_RULE,resp_hm_p0,3))
$(eval $(call RH_RULE,resp_hm_m0,0))
$(eval $(call RH_RULE,resp_hm_bl,2))
ROMS += rom/resp_hm_p0.a26 rom/resp_hm_m0.a26 rom/resp_hm_bl.a26

# hmove_c3.s: HMOVE right after WSYNC (cycle 3) with P0 placed on cycles 20..98; HMCLR written while the HMOVE runs (hmclr_mid.s)
define C3_RULE
rom/$(1).a26: hmove_c3.s tia_test.inc tia4k.cfg
	@mkdir -p rom; $(CA65) -D NUS=$(2) -D HMV=$$$$60 -o rom/$(1).o $$<; $(LD65) -C tia4k.cfg -o $$@ rom/$(1).o
endef
$(eval $(call C3_RULE,hmove_c3_n0,0))
$(eval $(call C3_RULE,hmove_c3_n5,5))
$(eval $(call C3_RULE,hmove_c3_n7,7))
rom/hmclr_mid.a26: hmclr_mid.s tia_test.inc tia4k.cfg
	@mkdir -p rom; $(CA65) -D WHAT=0 -o rom/hmclr_mid.o $<; $(LD65) -C tia4k.cfg -o $@ rom/hmclr_mid.o
ROMS += rom/hmove_c3_n0.a26 rom/hmove_c3_n5.a26 rom/hmove_c3_n7.a26 rom/hmclr_mid.a26

clean:
	rm -rf rom

# resmp_basic.s: RESMP0 with NUSIZ0 = 0, 5, 7 (single, double, quad) and 3 (two copies close)
RMP = n0:0 n3:3 n5:5 n7:7
define RMP_RULE
rom/resmp_$(1)_a.a26: resmp_basic.s tia_test.inc tia4k.cfg
	@mkdir -p rom; $(CA65) -D NUS=$(2) -D CBASE=2 -o rom/rm$(1)a.o $$<; $(LD65) -C tia4k.cfg -o $$@ rom/rm$(1)a.o
rom/resmp_$(1)_b.a26: resmp_basic.s tia_test.inc tia4k.cfg
	@mkdir -p rom; $(CA65) -D NUS=$(2) -D CBASE=38 -o rom/rm$(1)b.o $$<; $(LD65) -C tia4k.cfg -o $$@ rom/rm$(1)b.o
endef
$(foreach v,$(RMP),$(eval $(call RMP_RULE,$(word 1,$(subst :, ,$(v))),$(word 2,$(subst :, ,$(v))))))
ROMS += $(foreach v,$(RMP),rom/resmp_$(word 1,$(subst :, ,$(v)))_a.a26 rom/resmp_$(word 1,$(subst :, ,$(v)))_b.a26)

# pl_mid.s: a register changed during the draw (WHAT 0 = REFP0, 1 = GRP0, 2 = VDELP0)
define PM_RULE
rom/pl_mid_$(1).a26: pl_mid.s tia_test.inc tia4k.cfg
	@mkdir -p rom; $(CA65) -D WHAT=$(1) -o rom/pm$(1).o $$<; $(LD65) -C tia4k.cfg -o $$@ rom/pm$(1).o
endef
$(foreach w,0 1 2,$(eval $(call PM_RULE,$(w))))
ROMS += rom/pl_mid_0.a26 rom/pl_mid_1.a26 rom/pl_mid_2.a26

all: $(ROMS)
