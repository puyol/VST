
Require Import Coq.Strings.String.

Require Import compcert.common.AST.
Require Import compcert.common.Globalenvs.
Require Import compcert.common.Memory.
Require Import compcert.common.Values.
Require Import compcert.cfrontend.Clight.

Require Import veric.tycontext.
Require Import veric.semax_prog.

(** *Juicy safetyn*)
Require Import concurrency.semax_initial.
Require Import concurrency.semax_conc.
Require Import concurrency.semax_to_juicy_machine.
Require Import concurrency.permissions.

(** *Erasure Imports*)
Require Import concurrency.erasure_signature.
Require Import concurrency.erasure_proof.
Require Import concurrency.erasure_safety.

(** *SAFETY*)
Require Import concurrency.safety.

(** *SSROMEGA*)
Require Import Omega.
Require Import concurrency.ssromega.
Set Bullet Behavior "Strict Subproofs".

(** *Excluded middle*)
Require Import Coq.Logic.Classical_Prop.

(*The following variables represent a program satisfying some CSL*)
Section Clight_safety.
    Variables
      (CS : compspecs)
      (V : varspecs)
      (G : funspecs)
      (ext_link : string -> ident)
      (ext_link_inj : forall s1 s2, ext_link s1 = ext_link s2 -> s1 = s2)
      (prog : Ctypes.program _)
      (all_safe : semax_prog.semax_prog (Concurrent_Espec unit CS ext_link) prog V G)
      (init_mem_not_none : Genv.init_mem (Ctypes.program_of_program prog) <> None)
      (x: block)
      (block: (Genv.find_symbol (globalenv prog) (prog_main (Ctypes.program_of_program prog)) = Some x)).

    Notation init_jmem n:= (initial_jm CS V G ext_link prog all_safe init_mem_not_none n).
    Notation init_rmap n:=(Some (juicy_mem.m_phi (init_jmem n) )).
    Notation init_genv:=(globalenv prog).
    Notation init_point:=(Vptr (projT1 ((spr CS V G ext_link prog all_safe init_mem_not_none))) Integers.Int.zero).


    Section Csafety_Clight.
    (** The initial Juicy Machine *)
    Definition js_initial n := initial_machine_state CS V G ext_link prog all_safe
                                                     init_mem_not_none n.

    Definition Juicy_safety:=
      safety_initial_state CS V G ext_link ext_link_inj prog all_safe init_mem_not_none.

    Import JuicyMachineModule.THE_JUICY_MACHINE.JuicyMachine.
    Import JuicyMachineModule.THE_JUICY_MACHINE.SCH.


    (*this is showing the similarity between JM's initial machine and CoreSemantics initial machine*)
    Definition CoreInitial U r := (semantics.initial_core (MachineSemantics U r)).
    Lemma initial_equivalence: forall u r n
             (g:JuicyMachineModule.THE_JUICY_MACHINE.JSEM.ThreadPool.SEM.G)
             b,
          genv_genv g = Genv.globalenv (Ctypes.program_of_program prog) ->
          b =  projT1 ((spr CS V G ext_link prog all_safe init_mem_not_none)) ->
          r = Some (juicy_mem.m_phi (initial_jm CS V G ext_link prog all_safe init_mem_not_none  n)) ->
          CoreInitial u r 0 g
                      (juicy_mem.m_dry (initial_jm CS V G ext_link prog all_safe init_mem_not_none  n)) (Vptr b Integers.Int.zero) nil =
          Some (u, nil, initial_machine_state CS V G ext_link prog all_safe init_mem_not_none n, None).
        intros.
        unfold CoreInitial; simpl.
        unfold init_machine, JuicyMachineModule.THE_JUICY_MACHINE.JSEM.init_mach.
        unfold semantics.initial_core.
        unfold ErasureSafety.ErasureProof.JMS.the_sem.
        unfold JuicyMachineModule.THE_JUICY_MACHINE.JSEM.ThreadPool.SEM.Sem.
        rewrite JuicyMachineModule.THE_JUICY_MACHINE.SEM.CLN_msem.
        simpl.

        
        Lemma initial_equivalence_trivial:
          forall CS V G ext_link prog all_safe init_mem_not_none n,
            JuicyMachineModule.THE_JUICY_MACHINE.JSEM.initial_machine
              (juicy_mem.m_phi
                 (initial_jm CS V G ext_link prog all_safe init_mem_not_none n))
              (initial_corestate CS V G ext_link prog all_safe
                                 init_mem_not_none) =
            initial_machine_state CS V G ext_link prog all_safe init_mem_not_none n.
        Proof.
          intros; simpl.
          unfold initial_machine_state, JuicyMachineModule.THE_JUICY_MACHINE.JSEM.initial_machine; simpl.
          f_equal.
        Qed.
        
        rewrite <- initial_equivalence_trivial.
        subst r; simpl.
        rewrite H; simpl.
        destruct spr as (b' & c' & e & SPR); simpl in *.
        subst b'.
        
        f_equal.
        f_equal; simpl.
        f_equal; simpl.
        

        unfold initial_corestate.
        destruct spr as (b' & q & [e INIT'] & f'); simpl in *.
        simpl in INIT'.
        rewrite <- H in *.
        destruct (Genv.find_funct_ptr g b') eqn:find_f; inversion INIT'.
        f_equal.
    Qed.

    
    Lemma initial_equivalence': forall U n
             (g:JuicyMachineModule.THE_JUICY_MACHINE.JSEM.ThreadPool.SEM.G)
             ,
          genv_genv g = Genv.globalenv (Ctypes.program_of_program prog) ->
          (semantics.initial_core (MachineSemantics U (Some (juicy_mem.m_phi (initial_jm CS V G ext_link prog all_safe init_mem_not_none n)))))
            0 g
            (Vptr (projT1 ((spr CS V G ext_link prog all_safe init_mem_not_none))) Integers.Int.zero) nil =
                             Some (U, nil, initial_machine_state CS V G ext_link prog all_safe init_mem_not_none n).
        intros.
        eapply initial_equivalence; eauto.
    Qed.

    
    Lemma CoreInitial_juicy_safety:
      forall (U : semax_invariant.schedule) (n : nat),
      exists init_st,
        (semantics.initial_core (MachineSemantics U (init_rmap n))) 0 init_genv init_point nil =
        Some (U, nil, init_st) /\
       forall U',
       csafe (globalenv prog) (U', nil, init_st)
         (proj1_sig (init_mem prog init_mem_not_none)) n.
    Proof.
      eexists; split.
      rewrite initial_equivalence'; eauto.
      intros U'; eapply Juicy_safety.
    Qed.


    Check ErasureSafety.initial_safety.


    (** *Safety for Clight_new*)
    Import DryMachineSource.THE_DRY_MACHINE_SOURCE.DMS.DryConc.
    Lemma Initial_dry_csafety:
      forall (U : semax_invariant.schedule) (n : nat),
      exists init_U init_tr init_st,
        (semantics.initial_core (MachineSemantics U (Some ( getCurPerm (juicy_mem.m_dry (init_jmem n)), empty_map)))) 0 init_genv init_point nil =
        Some (init_U, init_tr, init_st) /\
        forall U' ,
       csafe (globalenv prog) (U', init_tr, init_st)
         (proj1_sig (init_mem prog init_mem_not_none)) n.
    Proof.
      intros U n.
      pose proof (CoreInitial_juicy_safety U n).
      destruct H as (init_jmach & INIT_ok & CSAFE).
      eapply ErasureSafety.initial_safety in INIT_ok; eauto.
      - destruct INIT_ok as (ds & INIT_ok & INV & MATCH); eauto.
        do 3 eexists; split; eauto.
        intros U'.
        eapply ErasureSafety.erasure_safety; eauto; simpl.
        econstructor; eauto.
      - simpl; unfold ErasureSafety.ErasureProof.match_rmap_perm; intros.
        split; auto; simpl.
        rewrite getCurPerm_correct.
        admit.
      - unfold ErasureSafety.ErasureProof.no_locks_perm.
        unfold initial_jm.
        destruct spr as (b' & q & [e INIT'] & jm); simpl in *.
        destruct (jm n) as (jm' & HH); simpl.
        admit.
    Admitted.


    Lemma dry_initial_state_equality:
    forall (U : semax_invariant.schedule) (n1 n2 : nat),
      (semantics.initial_core (MachineSemantics U (Some ( getCurPerm (juicy_mem.m_dry (init_jmem n1)), empty_map)))) 0 init_genv init_point nil =
      (semantics.initial_core (MachineSemantics U (Some ( getCurPerm (juicy_mem.m_dry (init_jmem n2)), empty_map)))) 0 init_genv init_point nil.
    Proof.
      intros; simpl.
      unfold init_machine, DryMachineSource.THE_DRY_MACHINE_SOURCE.DMS.DryMachine.init_mach.
      match goal with
      | [  |- context[semantics.initial_core ?a ?b ?c ?d ?e] ] =>
        destruct (semantics.initial_core a b c d e)
      end; f_equal; f_equal; simpl.
      f_equal; f_equal.
      unfold initial_jm.
      destruct spr as (b' & q & [e INIT'] & jm); simpl in *.
      destruct (jm n1) as [? [H1 ?]]; destruct (jm n2)  as [? [H2 ?]]; simpl.
      rewrite H1, H2; auto.
    Qed.
    
    Lemma Initial_dry_Csafety_stronger:
      forall (U : semax_invariant.schedule) (n : nat),
      exists init_U init_tr init_st,
        (semantics.initial_core (MachineSemantics U (Some ( getCurPerm (juicy_mem.m_dry (init_jmem n)), empty_map)))) 0 init_genv init_point nil =
        Some (init_U, init_tr, init_st) /\
        forall U' n',
       csafe (globalenv prog) (U', init_tr, init_st)
         (proj1_sig (init_mem prog init_mem_not_none)) n'.
    Proof.
      intros U n.
      pose proof (Initial_dry_csafety U n) as [init_U [ init_tr [init_st [HH ?]]]].
      do 3 eexists; split; eauto.
      intros U' n'.
      pose proof (Initial_dry_csafety U n') as [init_U' [ init_tr' [init_st' [HH' ?]]]].
      erewrite dry_initial_state_equality in HH'.
      erewrite HH' in HH. inversion HH; subst; auto.
    Qed.
      
End Csafety_Clight.

Section Ksafety_Clight.
  Import DryMachineSource.THE_DRY_MACHINE_SOURCE.DMS.DryConc.
  Import DryMachineSource.THE_DRY_MACHINE_SOURCE.SCH.
  Import DryMachineSource.THE_DRY_MACHINE_SOURCE.DMS.DryMachine.

  (** *First show Csafety -> Ksafety*)
  Lemma Clight_csafe2ksafe:
      forall ge st_ m,
        (forall U n, new_valid (nil, st_, m) U ->  csafe ge (U, nil, st_) m n) ->
        (forall U n, new_valid (nil, st_, m) U -> ksafe_new_step ge (U, nil, st_) m n).
    Proof.
      intros.
      assert (HH: forall (U : Sch), new_valid (nil, st_, m) U -> csafe ge (U, nil, st_) m n) by
      (intros; apply H; eauto). clear H.
      generalize ge st_ m HH U H0. clear.
      induction n.
      - econstructor.
      - intros. assert (VALID:= H0).
        eapply HH in H0.
        inversion H0; subst.
        + econstructor.
          * econstructor; eauto.
          * intros. unfold mk_nstate in *; simpl in *.
            eapply IHn; eauto. intros.
            apply csafe_monotone; auto.
        + econstructor.
          unfold new_step, mk_nstate, mk_ostate; simpl.
          econstructor 2.
          instantiate (1:= (nil, tp', m')); eauto.
          intros. eapply IHn; eauto.
          intros.
          simpl in Hsafe.
          clear H.
          unfold new_valid, correct_schedule in H1; simpl in *.
          destruct (schedPeek U0) eqn:PEEK0.
          2: econstructor; unfold halted; simpl;
            rewrite PEEK0; auto.
          
          eapply csafe_first_tid; eauto.
          simpl in Hstep.
          assert (new_valid (nil, tp', m') U).
          { eapply step_new_valid in Hstep.
            unfold mk_nstate in Hstep; simpl in *; eauto.
            unfold mk_nstate; simpl; eauto. }
          unfold new_valid, correct_schedule in H; simpl in *.
          inversion Hstep; subst; simpl in *;
            try match goal with
                | [ H: schedPeek ?U = Some _, H0: schedSkip U = U |- _ ] =>
                  symmetry in H0;
                    rewrite end_of_sch in H0;
                    rewrite H in H0; inversion H0
                end.
          (*All three cases are identical*)
          * (*init*)
            rewrite HschedN in *.
            rewrite PEEK0; f_equal.
            inversion Htstep; subst.
            symmetry.
            assert (HH2:forall i j, is_true (ssrbool.is_left (TID.eq_tid_dec i j)) -> i = j).
            { clear. intros. destruct (TID.eq_tid_dec i j); inversion H; auto. }
            apply HH2. eapply H1.
            -- eapply ErasureSafety.ErasureProof.DTP.gssThreadCC.
            -- intros HHH.
               unfold threadHalted in HHH.
               inversion HHH.
               simpl in Hcant.
               unfold ErasureSafety.ErasureProof.JMS.the_sem in Hcant; simpl in *.
               unfold JuicyMachineModule.THE_JUICY_MACHINE.JSEM.ThreadPool.SEM.Sem in Hcant.
               rewrite JuicyMachineModule.THE_JUICY_MACHINE.SEM.CLN_msem in Hcant.
               inversion Hcant.
          * rewrite PEEK0, HschedN in *.
            f_equal.
            inversion Htstep; subst.
            symmetry.
            assert (HH2:forall i j, is_true (ssrbool.is_left (TID.eq_tid_dec i j)) -> i = j).
            { clear. intros. destruct (TID.eq_tid_dec i j); inversion H; auto. }
            apply HH2. eapply H1.
            -- eapply ErasureSafety.ErasureProof.DTP.gssThreadCC.
            -- intros HHH.
               unfold threadHalted in HHH.
               inversion HHH.
               simpl in Hcant.
               unfold ErasureSafety.ErasureProof.JMS.the_sem in Hcant; simpl in *.
               unfold JuicyMachineModule.THE_JUICY_MACHINE.JSEM.ThreadPool.SEM.Sem in Hcant.
               rewrite JuicyMachineModule.THE_JUICY_MACHINE.SEM.CLN_msem in Hcant.
               inversion Hcant.
          * rewrite PEEK0, HschedN in *.
            f_equal.
            inversion Htstep; subst.
            symmetry.
            assert (HH2:forall i j, is_true (ssrbool.is_left (TID.eq_tid_dec i j)) -> i = j).
            { clear. intros. destruct (TID.eq_tid_dec i j); inversion H; auto. }
            apply HH2. eapply H1.
            -- eapply ErasureSafety.ErasureProof.DTP.gssThreadCC.
            -- intros HHH.
               unfold threadHalted in HHH.
               inversion HHH.
               simpl in Hcant.
               unfold ErasureSafety.ErasureProof.JMS.the_sem in Hcant; simpl in *.
               unfold JuicyMachineModule.THE_JUICY_MACHINE.JSEM.ThreadPool.SEM.Sem in Hcant.
               rewrite JuicyMachineModule.THE_JUICY_MACHINE.SEM.CLN_msem in Hcant.
               inversion Hcant.
        + (*machine step*)
          simpl in *.
          econstructor.
          unfold new_step, mk_nstate, mk_ostate; simpl.
          econstructor 2.
          instantiate (1:= (nil, tp', m')); eauto.
          intros. eapply IHn; eauto.


          Unshelve.
          eapply ErasureSafety.ErasureProof.DTP.cntUpdateC; eauto.
          eapply ErasureSafety.ErasureProof.DTP.cntUpdateC; eauto.
          eapply ErasureSafety.ErasureProof.DTP.cntUpdate; eauto.
                    
    Qed.

    Lemma init_schedule:
      forall U pmap n g p t init_mach,
        (semantics.initial_core (MachineSemantics U pmap) n g p t) = Some init_mach ->
        fst (fst init_mach) = U.
    Proof. intros. simpl in H. unfold init_machine,init_mach in H.
           destruct (semantics.initial_core ErasureSafety.ErasureProof.JMS.the_sem 0 g p);
             inversion H.
           destruct pmap; inversion H; auto.
    Qed.
    Lemma init_trace:
      forall U pmap n g p t init_mach,
        (semantics.initial_core (MachineSemantics U pmap) n g p t) = Some init_mach ->
        snd (fst init_mach) = nil.
    Proof. intros. simpl in H. unfold init_machine,init_mach in H.
           destruct (semantics.initial_core ErasureSafety.ErasureProof.JMS.the_sem 0 g p);
             inversion H.
           destruct pmap; inversion H; auto.
    Qed.

    Lemma init_schedule_all:
      forall U pmap n g p t init_mach,
        (semantics.initial_core (MachineSemantics U pmap) n g p t) = Some init_mach ->
        forall U'',
        correct_schedule (U'', snd (fst init_mach), snd init_mach) ->
       schedPeek U'' = Some 1  \/ schedPeek U'' = None .
    Admitted.
           
    Lemma Initial_dry_ksafety:
      forall (U : semax_invariant.schedule) (n : nat),
      exists init_U init_tr init_st,
        (semantics.initial_core (MachineSemantics U (Some ( getCurPerm (juicy_mem.m_dry (init_jmem n)), empty_map)))) 0 init_genv init_point nil =
        Some (init_U, init_tr, init_st) /\
        forall n' U',
       ksafe_new_step (globalenv prog) (U', init_tr, init_st)
         (proj1_sig (init_mem prog init_mem_not_none)) n'.
    Proof.
      intros.
      pose proof (Initial_dry_Csafety_stronger U n).
      destruct H as [init_U [init_tr [init_st [INIT_ok SAFE] ]]].
      do 3 eexists; split; eauto.
      
      
      pose proof (init_schedule _ _ _ _ _ _ _ INIT_ok).

      pose proof (init_trace _ _ _ _ _ _ _ INIT_ok).
        simpl in *.
        subst.
        induction n'; try solve[constructor].
      (** *Check if the schedule is empty, valid, or about to stutter*)
        intros U'; destruct U'.
      - (*nil case*)
        intros.
        econstructor.
        eapply halt_with_step.
        unfold mk_ostate, mk_nstate; auto.
        intros; eauto.
        unfold ksafe_new_step,mk_nstate in IHn'; simpl in IHn'.
        unfold mk_nstate; simpl; auto.
      - destruct (Compare_dec.zerop t).
        + subst. simpl.
          eapply Clight_csafe2ksafe; intros.
          * eapply SAFE.
          * unfold new_valid, correct_schedule, mk_ostate; simpl.
            intros j ? ? ? ?.
            unfold ThreadPool.containsThread in cnti; simpl in cnti.
            unfold init_machine,init_mach in INIT_ok.
            match goal with
            | [ H: context[semantics.initial_core ?a ?b ?c ?d ?e] |- _ ] =>
              destruct (semantics.initial_core a b c d e)
            end; inversion INIT_ok; subst.
            simpl in cnti.
            clear - cnti.
            destruct (TID.eq_tid_dec 0 j); auto.
            destruct j; try contradiction n; auto.
            simpl in cnti.
            compute in cnti; inversion cnti.
        +  econstructor.
           * eapply step_with_halt.
             unfold mk_ostate, mk_nstate; simpl.
             instantiate (4:=U').
             instantiate (2:= (nil, init_st,  (proj1_sig (init_mem prog init_mem_not_none))));
               simpl.
             eapply schedfail; simpl; eauto.
             -- unfold ThreadPool.containsThread; intros.
             unfold init_machine,init_mach in INIT_ok;
               match goal with
               | [ H: context[semantics.initial_core ?a ?b ?c ?d ?e] |- _ ] =>
                 destruct (semantics.initial_core a b c d e)
               end; inversion INIT_ok; subst.
             simpl. intros HH.
             destruct t; try omega.
            inversion HH.
             -- unfold init_machine,init_mach in INIT_ok;
               match goal with
               | [ H: context[semantics.initial_core ?a ?b ?c ?d ?e] |- _ ] =>
                 destruct (semantics.initial_core a b c d e) eqn:HH
               end; inversion INIT_ok; subst.
                eapply 
                  (DryMachineSource.THE_DRY_MACHINE_SOURCE.DryMachineLemmas.initial_invariant0 (getCurPerm (juicy_mem.m_dry (init_jmem n))) c).
           * intros. eapply IHn'.
    Qed.

    Lemma Initial_dry_ksafety_valid:
      forall (U : semax_invariant.schedule) (n : nat),
      exists init_U init_tr init_st,
        (semantics.initial_core (MachineSemantics U (Some ( getCurPerm (juicy_mem.m_dry (init_jmem n)), empty_map)))) 0 init_genv init_point nil =
        Some (init_U, init_tr, init_st) /\
        forall n' U',
          new_valid  (mk_nstate (U', init_tr, init_st)
                                (proj1_sig (init_mem prog init_mem_not_none))) U' ->
       ksafe_new_step (globalenv prog) (U', init_tr, init_st)
         (proj1_sig (init_mem prog init_mem_not_none)) n'.
    Proof.
      intros.
      pose proof (Initial_dry_Csafety_stronger U n).
      destruct H as [init_U [init_tr [init_st [INIT_ok SAFE] ]]].
      do 3 eexists; split; eauto.
      pose proof (init_schedule _ _ _ _ _ _ _ INIT_ok);
      pose proof (init_trace _ _ _ _ _ _ _ INIT_ok);
        simpl in *;
        subst.
      pose proof Clight_csafe2ksafe.
      unfold mk_nstate; simpl.
      intros; eapply H; eauto.
    Qed.

End Ksafety_Clight.

(*Infinite safety*)
Section safety_Clight.
  Import DryMachineSource.THE_DRY_MACHINE_SOURCE.DMS.DryConc.
  Import DryMachineSource.THE_DRY_MACHINE_SOURCE.SCH.
  Import DryMachineSource.THE_DRY_MACHINE_SOURCE.DMS.DryMachine.

  (*First we change validty to preserve bounded memory*)
  Lemma ksafe_new_step_ksafe_new_step_bounded: forall ge ds m,
        (forall (n : nat) (sch : Sch),
            new_valid  (mk_nstate (sch, nil, ds) m) sch ->
          ksafe_new_step ge
                                    (sch, nil, ds) m n) ->
      forall (n : nat) sch,
        new_valid_bound (mk_nstate (sch, nil, ds) m) sch ->
        safety.ksafe new_state Sch
                     (new_step ge) new_valid_bound (*Notice the stronger validity*)
                     (mk_nstate (sch, nil, ds) m) sch n.
    Proof.
      intros ge ds m KSAFE n.
      specialize (KSAFE n).
      generalize ds m KSAFE; clear ds m KSAFE.
      induction n.
      - intros ds m KSAFE sch.
        specialize (KSAFE sch).
        constructor 1.

      - intros ds m KSAFE sch [ VAL BOUND].
        specialize (KSAFE sch VAL).
        inversion KSAFE.
        econstructor ; eauto.
        intros U'' [ VAL'' BOUND''].
        unfold mk_nstate in IHn; simpl in IHn.
        destruct st' as [[tr' ds'] m'].
        cut (tr' = (@nil Events.machine_event)).
        + intros HH; subst tr'.
          eapply IHn; eauto.
          split; eauto.
        + inversion H0.
          * auto.
          * simpl in *; subst.
            inversion H2; simpl in *; auto.
    Qed.

  (* we prove safety that preserves bounded memory*)
  Lemma Initial_bounded_dry_safety:
      forall (U : semax_invariant.schedule) (n : nat),
      exists init_U init_tr init_st,
        (semantics.initial_core (MachineSemantics U (Some ( getCurPerm (juicy_mem.m_dry (init_jmem n)), empty_map)))) 0 init_genv init_point nil =
        Some (init_U, init_tr, init_st) /\
        forall U',
          new_valid_bound (mk_nstate (U', init_tr, init_st) (proj1_sig (init_mem prog init_mem_not_none))) U' ->
       safe_new_step_bound (globalenv prog) (U', init_tr, init_st)
         (proj1_sig (init_mem prog init_mem_not_none)).
  Proof.
    intros.
    destruct (Initial_dry_ksafety U n) as (INIT_U & INIT_tr & INIT_st & INIT_ok & SAFE).
    do 3 eexists; split; eauto.
    pose proof (init_schedule _ _ _ _ _ _ _ INIT_ok);
      pose proof (init_trace _ _ _ _ _ _ _ INIT_ok);
      simpl in *; subst.
    unfold safe_new_step.
    intros.
    eapply ksafe_safe'; eauto.
    - eapply classic.
    - intros; eapply DryMachineSource.THE_DRY_MACHINE_SOURCE.FiniteBranching.finite_branching.
    -  intros.
       unfold mk_nstate; simpl.
       unfold ksafe_new_step, mk_nstate in SAFE; simpl in SAFE.
       eapply ksafe_new_step_ksafe_new_step_bounded; eauto.
       intros; eapply SAFE.
  Qed.

  (*Facts aboud bounded memory, show it's preserved...*)
  Lemma bounded_mem_step:
            forall ge sm m sm' m',
          MachStep ge sm m sm' m' ->
          bounded_mem m ->
          bounded_mem m'.
    Proof.
      intros.
      inversion H; eauto; simpl in *; subst; eauto.
      - (*thread step *)
        clear - H0 Htstep .
        inversion Htstep; subst.
        generalize Hcorestep; eauto;  simpl.
        unfold ThreadPool.SEM.Sem,
              DryMachineSource.THE_DRY_MACHINE_SOURCE.DMS.SEM.Sem,
              DryMachineSource.THE_DRY_MACHINE_SOURCE.DMS.SEM.CLN_evsem.
        intros HH.
        eapply event_semantics.ev_step_ax1 in HH.
        simpl in HH.
        unfold semantics.corestep in HH; simpl in HH.
        unfold semantics.csem in HH; simpl in HH.
        rewrite ClightSemantincsForMachines.ClightSEM.CLN_msem in HH.
        simpl in HH.
        eapply Clight_bounds.CLight_step_mem_bound in HH; eauto.
        eapply Clight_bounds.bounded_getMaxPerm in H0; eauto.
      - inversion Htstep; eauto; simpl in *; subst; auto;
        eapply Clight_bounds.store_bounded; try eapply Hstore;
        eapply Clight_bounds.bounded_getMaxPerm; eauto.
    Qed.

    Lemma safe_new_step_bound_safe_new_step: forall sch ds m,
        new_valid_bound (nil, ds, m) sch ->
        safe_new_step_bound  (globalenv prog) (sch, nil, ds) m ->
            safe_new_step  (globalenv prog) (sch, nil, ds) m.
    Proof.
      unfold safe_new_step,
              safe_new_step_bound,
              mk_nstate ; simpl; eauto.
      cofix.
      intros sch ds m [ VAL BOUND] SAFE.
      inversion SAFE.
      econstructor; eauto.
      intros.
      assert (new_valid_bound st' U'').
      { split; eauto.
        destruct st' as [[? ?] m']; simpl in *.
        inversion H.
        - simpl in *; subst; auto.
        - simpl in *; subst.
          unfold mk_ostate in H2; simpl in *.
          eapply bounded_mem_step; eauto. }

      destruct st' as [[tr' ds'] m']; simpl in *.

      assert (tr' = nil).
      { inversion H; auto.
        simpl in *; subst.
        inversion H3; simpl in *; subst; auto.
      }

      subst tr'.
      eapply safe_new_step_bound_safe_new_step; eauto.
      Guarded.
    Qed.

    Lemma bounded_empty_mem:
           bounded_mem Mem.empty.
        Proof. intros b0 f.
               intros HH.
               exists 0%Z. exists 0%Z.
               split.
               - intros.
                 unfold getMaxPerm, PMap.map in HH.
                 simpl in HH.
                 rewrite PTree.gleaf in HH; inversion HH.
               - intros.
                 unfold getMaxPerm, PMap.map in HH.
                 simpl in HH.
                 rewrite PTree.gleaf in HH; inversion HH.
        Qed.
    Lemma bounded_initial_mem:
      bounded_mem (proj1_sig (init_mem prog init_mem_not_none)).
      unfold bounded_mem, bounded_maps.bounded_map, init_mem, init_m.
      destruct (Genv.init_mem (Ctypes.program_of_program prog)) eqn:HH;
          [ |exfalso; apply init_mem_not_none; auto].
      generalize HH; eauto; clear HH.
      pose (K:= (prog_defs (Ctypes.program_of_program prog))).
      pose (m':= Mem.empty).
      unfold Genv.init_mem.
      assert ( bounded_mem m').
      { subst; apply bounded_empty_mem. }
      generalize (H); clear H.
      fold K m'.
      generalize (m'); clear m'.
      induction K.
      - intros ? ? HH; inversion HH.
        simpl.
        subst; eauto.
        
      - intros M BM; simpl.
        destruct (Genv.alloc_global (Genv.globalenv (Ctypes.program_of_program prog)) M a) eqn: AA;
            try solve[intros HH; inversion HH].
          intros HH.
          pose (@Clight_bounds.alloc_global_bounded
                  _ _
                  (Genv.globalenv (Ctypes.program_of_program prog))
               M m0 a).
          eapply b in BM; eauto.
    Qed.

    Lemma Initial_dry_safety:
      forall (U : semax_invariant.schedule) (n : nat),
      exists init_U init_tr init_st,
        (semantics.initial_core (MachineSemantics U (Some ( getCurPerm (juicy_mem.m_dry (init_jmem n)), empty_map)))) 0 init_genv init_point nil =
        Some (init_U, init_tr, init_st) /\
        forall U',
          new_valid (mk_nstate (U', init_tr, init_st) (proj1_sig (init_mem prog init_mem_not_none))) U' ->
       safe_new_step_bound (globalenv prog) (U', init_tr, init_st)
         (proj1_sig (init_mem prog init_mem_not_none)).
  Proof.
    intros.
    destruct (Initial_bounded_dry_safety U n) as
        (INIT_U & INIT_tr & INIT_st & INIT_ok & SAFE).
    do 3 eexists; split; eauto.
    intros; eapply SAFE.
    split; eauto.
    unfold mk_nstate; simpl.
    eapply bounded_initial_mem.
  Qed.

  Lemma Initial_dry_safety_concur:
      forall (U : semax_invariant.schedule) (n : nat),
      exists init_st,
        (machine_semantics.initial_machine (new_MachineSemantics U (Some ( getCurPerm (juicy_mem.m_dry (init_jmem n)), empty_map)))) init_genv init_point nil =
        Some (init_st) /\
        forall U',
          new_valid (mk_nstate (U', nil, init_st) (proj1_sig (init_mem prog init_mem_not_none))) U' ->
       safe_new_step_bound (globalenv prog) (U', nil, init_st)
         (proj1_sig (init_mem prog init_mem_not_none)).
  Proof.
    intros.
    destruct (Initial_dry_safety U n) as
        (INIT_U & INIT_tr & INIT_st & INIT_ok & SAFE).
    exists INIT_st; split; eauto.
    - simpl; unfold init_machine'; simpl.
      simpl in INIT_ok. unfold init_machine in INIT_ok.
      match goal with
      | [ H: context[init_mach ?a ?b ?c ?d] |- _ ] =>
        destruct (init_mach a b c d) eqn:HH;
          inversion INIT_ok; subst; eauto
      end.
    - eapply init_trace in INIT_ok.
      simpl in INIT_ok; subst.
      eauto.
  Qed.


End safety_Clight.

End Clight_safety.