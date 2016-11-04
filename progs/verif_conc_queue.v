Require Import progs.conclib.
Require Import progs.conc_queue.
Require Import progs.conc_queue_specs.
Require Import floyd.library.

(* This lets us use a library as a client. *)
Axiom semax_func_mono : forall {Espec : OracleKind} {C : compspecs} V G fs G' G2,
  semax_func V G fs G' -> incl G G2 -> semax_func V G2 fs G'.

Definition acquire_spec := DECLARE _acquire acquire_spec.
Definition release_spec := DECLARE _release release_spec.
Definition makelock_spec := DECLARE _makelock (makelock_spec _).
Definition freelock_spec := DECLARE _freelock (freelock_spec _).
Definition makecond_spec := DECLARE _makecond (makecond_spec _).
Definition freecond_spec := DECLARE _freecond (freecond_spec _).
Definition wait_spec := DECLARE _waitcond (wait2_spec _).
Definition signal_spec := DECLARE _signalcond (signal_spec _).

Definition q_new_spec := DECLARE _q_new q_new_spec'.
Definition q_del_spec := DECLARE _q_del q_del_spec'.
Definition q_add_spec := DECLARE _q_add q_add_spec'.
Definition q_remove_spec := DECLARE _q_remove q_remove_spec'.
Definition q_tryremove_spec := DECLARE _q_tryremove q_tryremove_spec'.

Definition surely_malloc_spec :=
  DECLARE _surely_malloc
   WITH n:Z
   PRE [ _n OF tuint ]
       PROP (0 <= n <= Int.max_unsigned)
       LOCAL (temp _n (Vint (Int.repr n)))
       SEP ()
    POST [ tptr tvoid ] EX p:_,
       PROP ()
       LOCAL (temp ret_temp p)
       SEP (malloc_token Tsh n p * memory_block Tsh n p).

Definition Gprog : funspecs := ltac:(with_library prog
  [surely_malloc_spec; acquire_spec; release_spec; makelock_spec; freelock_spec;
   makecond_spec; freecond_spec; wait_spec; signal_spec;
   q_new_spec; q_del_spec; q_add_spec; q_remove_spec; q_tryremove_spec]).

Lemma body_surely_malloc: semax_body Vprog Gprog f_surely_malloc surely_malloc_spec.
Proof.
  start_function. 
  forward_call (* p = malloc(n); *)
     n.
  Intros p.
  forward_if
  (PROP ( )
   LOCAL (temp _p p)
   SEP (malloc_token Tsh n p * memory_block Tsh n p)).
*
  if_tac.
    subst p. entailer!.
    entailer!.
*
    forward_call tt.
    contradiction.
*
    if_tac.
    + forward. subst p. inv H0.
    + Intros. forward. entailer!.
*
  forward. Exists p; entailer!.
Qed.

Lemma all_ptrs : forall t P vals, fold_right sepcon emp (map (fun x => let '(p, v) := x in
  !!(P v) && (data_at Tsh t v p * malloc_token Tsh (sizeof t) p)) vals) |--
  !!(Forall isptr (map fst vals)).
Proof.
  induction vals; simpl; intros; entailer.
  destruct a.
  rewrite data_at_isptr.
  eapply derives_trans; [apply saturate_aux20 with (P' := isptr v)|].
  { Intros; apply prop_right; auto. }
  { apply IHvals; auto. }
  normalize.
Qed.

Lemma vals_precise : forall r t P vals1 vals2 r1 r2
  (Hvals : map fst vals1 = map fst vals2)
  (Hvals1 : predicates_hered.app_pred(A := compcert_rmaps.R.rmap) (fold_right sepcon emp
    (map (fun x => let '(p, v) := x in !!(P v) && (data_at Tsh t v p * malloc_token Tsh (sizeof t) p)) vals1)) r1)
  (Hvals2 : predicates_hered.app_pred(A := compcert_rmaps.R.rmap) (fold_right sepcon emp
    (map (fun x => let '(p, v) := x in !!(P v) && (data_at Tsh t v p * malloc_token Tsh (sizeof t) p)) vals2)) r2)
  (Hr1 : sepalg.join_sub r1 r) (Hr2 : sepalg.join_sub r2 r), r1 = r2.
Proof.
  induction vals1; simpl; intros; destruct vals2; inversion Hvals.
  - apply sepalg.same_identity with (a := r); auto.
    { destruct Hr1 as (? & H); specialize (Hvals1 _ _ H); subst; auto. }
    { destruct Hr2 as (? & H); specialize (Hvals2 _ _ H); subst; auto. }
  - destruct a, p; simpl in *; subst.
    destruct Hvals1 as (? & r1b & ? & (? & r1a & ? & ? & Hh1 & Hm1) & ?),
      Hvals2 as (? & r2b & ? & (? & r2a & ? & ? & Hh2 & Hm2) & ?).
    exploit malloc_token_precise.
    { apply Hm1. }
    { apply Hm2. }
    { join_sub. }
    { join_sub. }
    assert (r1a = r2a); [|intros; subst].
    { apply data_at_data_at_ in Hh1; apply data_at_data_at_ in Hh2.
      eapply data_at__precise with (sh := Tsh); auto; eauto; join_sub. }
    assert (r1b = r2b); [|subst].
    { eapply IHvals1; eauto; join_sub. }
    join_inj.
Qed.

Axiom ghost_precise : forall sh {t} p, precise (EX f : share * hist t, ghost sh f p).

Lemma tqueue_inj : forall r (buf1 buf2 : list val) len1 len2 head1 head2 tail1 tail2
  (addc1 addc2 remc1 remc2 : val) p r1 r2
  (Hp1 : predicates_hered.app_pred(A := compcert_rmaps.R.rmap)
     (data_at Tsh tqueue (buf1, (vint len1, (vint head1, (vint tail1, (addc1, remc1))))) p) r1)
  (Hp2 : predicates_hered.app_pred(A := compcert_rmaps.R.rmap)
     (data_at Tsh tqueue (buf2, (vint len2, (vint head2, (vint tail2, (addc2, remc2))))) p) r2)
  (Hr1 : sepalg.join_sub r1 r) (Hr2 : sepalg.join_sub r2 r)
  (Hbuf1 : Forall (fun v => v <> Vundef) buf1) (Hl1 : Zlength buf1 = MAX)
  (Hbuf2 : Forall (fun v => v <> Vundef) buf2) (Hl2 : Zlength buf2 = MAX)
  (Haddc1 : addc1 <> Vundef) (Haddc2 : addc2 <> Vundef) (Hremc1 : remc1 <> Vundef) (Hremc2 : remc2 <> Vundef),
  r1 = r2 /\ buf1 = buf2 /\ Int.repr len1 = Int.repr len2 /\ Int.repr head1 = Int.repr head2 /\
  Int.repr tail1 = Int.repr tail2 /\ addc1 = addc2 /\ remc1 = remc2.
Proof.
  intros.
  unfold data_at in Hp1, Hp2; erewrite field_at_Tstruct in Hp1, Hp2; try reflexivity; try apply JMeq_refl.
  simpl in Hp1, Hp2; unfold withspacer in Hp1, Hp2; simpl in Hp1, Hp2.
  destruct Hp1 as (? & ? & ? & (? & Hb1) & ? & ? & ? & (? & Hlen1) & ? & ? & ? & (? & Hhead1) & ? & ? & ? &
    (? & Htail1) & ? & ? & ? & (? & Hadd1) & ? & Hrem1).
  destruct Hp2 as (? & ? & ? & (? & Hb2) & ? & ? & ? & (? & Hlen2) & ? & ? & ? & (? & Hhead2) & ? & ? & ? &
    (? & Htail2) & ? & ? & ? & (? & Hadd2) & ? & Hrem2); unfold at_offset in *.
  assert (readable_share Tsh) as Hread by auto.
  exploit (mapsto_inj _ _ _ _ _ _ _ r Hread Hrem1 Hrem2); auto; try join_sub.
  exploit (mapsto_inj _ _ _ _ _ _ _ r Hread Hadd1 Hadd2); auto; try join_sub.
  exploit (mapsto_inj _ _ _ _ _ _ _ r Hread Htail1 Htail2); auto; try join_sub; try discriminate.
  exploit (mapsto_inj _ _ _ _ _ _ _ r Hread Hhead1 Hhead2); auto; try join_sub; try discriminate.
  exploit (mapsto_inj _ _ _ _ _ _ _ r Hread Hlen1 Hlen2); auto; try join_sub; try discriminate.
  exploit (data_at_ptr_array_inj _ _ _ _ _ _ _ _ r Hread Hb1 Hb2); auto; try join_sub.
  unfold repinject.
  intros (? & ?) (? & ?) (? & ?) (? & ?) (? & ?) (? & ?); subst; join_inj.
  repeat split; auto; congruence.
Qed.

Lemma q_inv_precise : forall t P p lock gsh2, precise (q_lock_pred t P p lock gsh2).
Proof.
  unfold q_lock_pred, q_lock_pred'; intros ???????? H1 H2 Hw1 Hw2.
  destruct H1 as (vals1 & head1 & addc1 & remc1 & h1 & (? & ? & ?) & ? & ? & ? & (? & ? & ? & (? & ? & ? &
    (? & ? & ? & (? & ? & ? & (? & ? & ? & (? & ? & ? & (? & ? & ? & (Hq1 & Haddc1)) & Hremc1) & Htv1) & Hta1) &
    Htr1) & Htl1) & Hghost1) & Hvals1),
  H2 as (vals2 & head2 & addc2 & remc2 & h2 & (? & ? & ?) & ? & ? & ? & (? & ? & ? & (? & ? & ? &
    (? & ? & ? & (? & ? & ? & (? & ? & ? & (? & ? & ? & (? & ? & ? & (Hq2 & Haddc2)) & Hremc2) & Htv2) & Hta2) &
    Htr2) & Htl2) & Hghost2) & Hvals2).
  pose proof (all_ptrs _ _ _ _ Hvals1) as Hptrs1.
  pose proof (all_ptrs _ _ _ _ Hvals2) as Hptrs2.
  exploit (tqueue_inj w _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ Hq1 Hq2); try join_sub.
  { apply Forall_rotate, Forall_complete; auto; [|discriminate].
    eapply Forall_impl; [|apply Hptrs1]; destruct a; try contradiction; discriminate. }
  { rewrite Zlength_rotate; try rewrite Zlength_complete; try omega; rewrite Zlength_map; auto. }
  { apply Forall_rotate, Forall_complete; auto; [|discriminate].
    eapply Forall_impl; [|apply Hptrs2]; destruct a; try contradiction; discriminate. }
  { rewrite Zlength_rotate; try rewrite Zlength_complete; try omega; rewrite Zlength_map; auto. }
  { rewrite cond_var_isptr in Haddc1; destruct Haddc1, addc1; try contradiction; discriminate. }
  { rewrite cond_var_isptr in Haddc2; destruct Haddc2, addc2; try contradiction; discriminate. }
  { rewrite cond_var_isptr in Hremc1; destruct Hremc1, remc1; try contradiction; discriminate. }
  { rewrite cond_var_isptr in Hremc2; destruct Hremc2, remc2; try contradiction; discriminate. }
  intros (? & ? & Hlen & ? & ? & ? & ?); subst.
  exploit (ghost_precise(t := t) gsh2 p w).
  { eexists; apply Hghost1. }
  { eexists; apply Hghost2. }
  { join_sub. }
  { join_sub. }
  intro; subst.
  assert (head1 = head2) as ->.
  { apply repr_inj_unsigned; auto; split; try omega; transitivity MAX; try omega; unfold MAX; computable. }
  assert (length vals1 = length vals2).
  { apply repr_inj_unsigned in Hlen; rewrite Zlength_correct in Hlen.
    rewrite Zlength_correct in Hlen; Omega0.
    - split; [rewrite Zlength_correct; omega|]; transitivity MAX; try omega; unfold MAX; computable.
    - split; [rewrite Zlength_correct; omega|]; transitivity MAX; try omega; unfold MAX; computable. }
  assert (map fst vals1 = map fst vals2) as Heq.
  { eapply complete_inj; [|rewrite !map_length; auto].
    eapply rotate_inj; eauto; try omega.
    repeat rewrite length_complete; try rewrite Zlength_map; auto.
    rewrite Zlength_complete; try rewrite Zlength_map; omega. }
  rewrite Heq in *.
  exploit (vals_precise w _ _ _ _ _ _ Heq Hvals1 Hvals2); auto; try join_sub.
  assert (readable_share Tsh) as Hread by auto.
  exploit (cond_var_precise _ _ Hread w _ _ Haddc1 Haddc2); try join_sub.
  exploit (cond_var_precise _ _ Hread w _ _ Hremc1 Hremc2); try join_sub.
  exploit (malloc_token_precise _ _ _ w _ _ Hta1 Hta2); try join_sub.
  exploit (malloc_token_precise _ _ _ w _ _ Htr1 Htr2); try join_sub.
  exploit (malloc_token_precise _ _ _ w _ _ Htv1 Htv2); try join_sub.
  exploit (malloc_token_precise _ _ _ w _ _ Htl1 Htl2); try join_sub.
  intros; subst; join_inj.
Qed.

Lemma q_inv_positive : forall t P p lock gsh2, positive_mpred (q_lock_pred t P p lock gsh2).
Proof.
  intros; simpl.
  repeat (apply ex_positive; intro).
  apply positive_andp2.
  do 7 apply positive_sepcon1; apply positive_sepcon2; auto.
Qed.
Hint Resolve q_inv_precise q_inv_positive.

Lemma malloc_compat : forall sh t p, legal_alignas_type t = true ->
  legal_cosu_type t = true ->
  complete_type cenv_cs t = true -> (alignof t | natural_alignment) ->
  malloc_token sh (sizeof t) p = !!field_compatible t [] p && malloc_token sh (sizeof t) p.
Proof.
  intros; rewrite andp_comm; apply add_andp; entailer!.
  apply malloc_compatible_field_compatible; auto.
Qed.

Lemma body_q_new : semax_body Vprog Gprog f_q_new q_new_spec.
Proof.
  unfold q_new_spec, q_new_spec'; start_function.
  forward_call (sizeof tqueue_t).
  { simpl; computable. }
  Intros p.
  assert (alignof tqueue_t | natural_alignment).
  { simpl; unfold align_attr; simpl.
    exists 2; auto. }
  rewrite malloc_compat; auto; Intros.
  rewrite memory_block_data_at_; auto.
  forward.
  Intros.
  assert (field_compatible tqueue [] p /\ field_compatible (tptr tlock) [] (offset_val 60 p)) as (? & ?).
  { unfold field_compatible in *; repeat match goal with H : _ /\ _ |- _ => destruct H end.
    destruct p as [| | | | | b o]; try contradiction.
    assert (Int.unsigned (Int.add o (Int.repr 60)) = Int.unsigned o + 60) as Ho.
    { rewrite Int.unsigned_add_carry.
      unfold Int.add_carry.
      rewrite Int.unsigned_repr, Int.unsigned_zero; [|computable].
      destruct (zlt _ Int.modulus); simpl in *; omega. }
    repeat split; auto; simpl in *; try omega.
    rewrite Ho; unfold align_attr in *; simpl in *.
    apply Z.divide_add_r; auto.
    exists 15; auto. }
  forward_for_simple_bound MAX (EX i : Z, PROP () LOCAL (temp _q p; temp _newq p)
    SEP (malloc_token Tsh (sizeof tqueue_t) p;
         @data_at CompSpecs Tsh tqueue (repeat (vint 0) (Z.to_nat i) ++ repeat Vundef (Z.to_nat (MAX - i)),
           (Vundef, (Vundef, (Vundef, (Vundef, Vundef))))) p;
         @data_at_ CompSpecs Tsh (tptr tlock) (offset_val 60 p))).
  { unfold MAX; computable. }
  { unfold MAX; computable. }
  { unfold fold_right; entailer!.
    unfold data_at_, field_at_; unfold_field_at 1%nat.
    unfold data_at, field_at, at_offset; simpl; entailer. }
  { forward.
    go_lower.
    apply andp_right; [apply prop_right; split; auto; omega|].
    apply andp_right; [apply prop_right; auto|].
    cancel.
    rewrite upd_Znth_app2; repeat rewrite Zlength_repeat; repeat rewrite Z2Nat.id; try omega.
    rewrite Zminus_diag, upd_Znth0, sublist_repeat; try rewrite Zlength_repeat, Z2Nat.id; try omega.
    rewrite Z2Nat.inj_add, repeat_plus; try omega; simpl.
    rewrite <- app_assoc; replace (MAX - i - 1) with (MAX - (i + 1)) by omega; cancel. }
  rewrite Zminus_diag, app_nil_r.
  forward.
  forward.
  forward.
  forward_call (sizeof tint).
  { simpl; computable. }
  Intros addc.
  rewrite malloc_compat with (p := addc); auto; Intros.
  rewrite memory_block_data_at_; auto.
  forward_call (addc, Tsh).
  { unfold tcond; cancel. }
  forward.
  forward_call (sizeof tint).
  { simpl; computable. }
  Intros remc.
  rewrite malloc_compat with (p := remc); auto; Intros.
  rewrite memory_block_data_at_; auto.
  forward_call (remc, Tsh).
  { unfold tcond; cancel. }
  forward.
  forward_call (sizeof tlock).
  { admit. } (* lock size broken *)
  { simpl; computable. }
  Intros lock.
  rewrite malloc_compat with (p := lock); auto; Intros.
  rewrite memory_block_data_at_; auto.
  destruct Q as (t, P).
  forward_call (lock, Tsh, q_lock_pred t P p lock gsh2).
  gather_SEP 7 8; replace_SEP 0 (data_at Tsh tqueue_t (repeat (vint 0) (Z.to_nat MAX),
           (vint 0, (vint 0, (vint 0, (addc, remc)))), Vundef) p).
  { go_lowerx.
    unfold_data_at 1%nat.
    unfold data_at_, field_at_, field_at, at_offset; simpl.
    rewrite !sem_cast_neutral_ptr; auto.
    rewrite !field_compatible_cons; simpl; Intros.
    apply andp_right; [apply prop_right; unfold in_members; simpl; split; [|split; [|split]]; auto|].
    rewrite sepcon_emp, !isptr_offset_val_zero; auto. }
  apply new_ghost with (t' := t).
  forward.
  forward_call (lock, Tsh, q_lock_pred t P p lock gsh2).
  { lock_props.
    unfold q_lock_pred, q_lock_pred'; simpl.
    Exists ([] : list (val * reptype t)) 0 addc remc ([] : hist t).
    rewrite Zlength_nil; simpl; cancel.
    rewrite sepcon_andp_prop'.
    apply andp_right; [apply prop_right|].
    { repeat split; auto; unfold MAX; try omega; try computable. }
    cancel.
    subst Frame; instantiate (1 := [field_at Tsh tqueue_t [StructField _lock] lock p; ghost gsh1 (Tsh, []) p]);
      simpl.
    unfold_field_at 1%nat.
    erewrite <- ghost_share_join with (h1 := []); eauto.
    simpl; cancel.
    rewrite (sepcon_comm _ (@ghost _ t _ _)), !sepcon_assoc; apply sepcon_derives; auto.
    unfold data_at, field_at; simpl.
    rewrite !field_compatible_cons; simpl; Intros.
    apply andp_right; [apply prop_right; unfold in_members; simpl; split; [|split]; auto|].
    rewrite sem_cast_neutral_ptr; auto. }
  forward.
  Exists p lock.
  unfold lqueue; simpl; entailer!; auto.
Admitted.

Lemma list_incl_refl : forall {A} (l : list A), list_incl l l.
Proof.
  induction l; auto.
Qed.
Hint Resolve list_incl_refl.

Lemma consistent_inj : forall {t} (h : hist t) a b b' (Hb : consistent h a b) (Hb' : consistent h a b'), b = b'.
Proof.
  induction h; simpl; intros.
  - subst; auto.
  - destruct a; eauto.
    destruct a0; [contradiction|].
    destruct Hb, Hb'; eauto.
Qed.

Lemma body_q_del : semax_body Vprog Gprog f_q_del q_del_spec.
Proof.
  unfold q_del_spec, q_del_spec'; start_function.
  destruct Q as (t, (P, h)).
  unfold lqueue; rewrite lock_inv_isptr; Intros.
  forward.
  forward_call (lock, Tsh, q_lock_pred t P p lock gsh2).
  forward_call (lock, Tsh, q_lock_pred t P p lock gsh2).
  { lock_props. }
  unfold q_lock_pred, q_lock_pred'; Intros vals head addc remc h'.
  forward_call (lock, sizeof tlock).
  { simpl; cancel.
    rewrite !sepcon_assoc; apply sepcon_derives; [apply data_at__memory_block_cancel | cancel]. }
  forward.
  rewrite data_at_isptr, (cond_var_isptr _ addc), (cond_var_isptr _ remc); Intros.
  rewrite isptr_offset_val_zero; auto.
  forward.
  forward_call (addc, Tsh).
  forward_call (addc, sizeof tcond).
  { simpl; cancel.
    rewrite !sepcon_assoc; apply sepcon_derives; [apply data_at__memory_block_cancel | cancel]. }
  forward.
  forward_call (remc, Tsh).
  forward_call (remc, sizeof tcond).
  { simpl; cancel.
    repeat rewrite sepcon_assoc; apply sepcon_derives; [apply data_at__memory_block_cancel | cancel]. }
  gather_SEP 2 5; rewrite sepcon_comm.
  replace_SEP 0 (!!(h' = h) && ghost Tsh (Tsh, h) p).
  { go_lower.
    eapply derives_trans; [apply prop_and_same_derives, ghost_inj_Tsh|].
    Intros; subst.
    rewrite ghost_share_join; auto; entailer!. }
  Intros; subst.
  exploit (consistent_inj h [] [] vals); auto; intro; subst; simpl.
  rewrite Zlength_nil.
  gather_SEP 1 4; replace_SEP 0 (data_at Tsh tqueue_t (rotate (complete MAX []) head MAX,
     (vint 0, (vint head, (vint ((head + 0) mod MAX), (addc, remc)))), lock) p).
  { unfold_data_at 2%nat; entailer!.
    unfold data_at, field_at; Intros; simpl.
    apply andp_right; [|simple apply derives_refl].
    rewrite field_compatible_cons; unfold in_members; simpl; entailer!. }
  forward_call (p, sizeof tqueue_t).
  { rewrite (sepcon_comm (malloc_token _ _ _)).
    rewrite !sepcon_assoc; apply sepcon_derives; [apply data_at_memory_block | simpl; cancel]. }
  forward.
  (* Do we want to deallocate the ghost? *)
Admitted.

Lemma consistent_trans : forall {t} (h1 h2 : hist t) a b c, consistent h1 a b -> consistent h2 b c ->
  consistent (h1 ++ h2) a c.
Proof.
  induction h1; simpl; intros; subst; auto.
  destruct a; eauto.
  destruct a0; [contradiction | destruct H; eauto].
Qed.

Corollary consistent_snoc_add : forall {t} (h : hist t) a b e v, consistent h a b ->
  consistent (h ++ [QAdd e v]) a (b ++ [(e, v)]).
Proof.
  intros; eapply consistent_trans; simpl; eauto.
Qed.

Corollary consistent_cons_rem : forall {t} (h : hist t) a b e v, consistent h a ((e, v) :: b) ->
  consistent (h ++ [QRem e v]) a b.
Proof.
  intros; eapply consistent_trans; eauto; simpl; auto.
Qed.

Lemma list_incl_app2 : forall {A} (l l1 l2 : list A), list_incl l l2 -> list_incl l (l1 ++ l2).
Proof.
  induction l1; auto; intros.
  simpl; constructor; auto.
Qed.

Lemma list_incl_app : forall {A} (l1 l2 l1' l2' : list A), list_incl l1 l2 -> list_incl l1' l2' ->
  list_incl (l1 ++ l1') (l2 ++ l2').
Proof.
  induction 1; intros.
  - simpl; apply list_incl_app2; auto.
  - simpl; constructor; auto.
  - simpl; constructor 3; auto.
Qed.

Lemma body_q_add : semax_body Vprog Gprog f_q_add q_add_spec.
Proof.
  unfold q_add_spec, q_add_spec'.
  start_function.
  destruct Q as (t, ((P, h), v)).
  unfold lqueue; rewrite lock_inv_isptr; Intros.
  forward.
  forward_call (lock, sh, q_lock_pred t P p lock gsh2).
  unfold q_lock_pred at 2; unfold q_lock_pred'; Intros vals head addc remc h'.
  forward.
  rewrite data_at_isptr; Intros; rewrite isptr_offset_val_zero; auto.
  forward.
  forward_while (EX vals : _, EX head : Z, EX addc : val, EX remc : val, EX h' : hist t,
   PROP ()
   LOCAL (temp _len (vint (Zlength vals)); temp _q p; temp _l lock; temp _tgt p; temp _r e)
   SEP (lock_inv sh lock (q_lock_pred t P p lock gsh2);
        q_lock_pred' t P p vals head addc remc lock gsh2 h';
        @field_at CompSpecs sh tqueue_t [StructField _lock] lock p;
        @data_at CompSpecs Tsh t v e; malloc_token Tsh (sizeof t) e; ghost gsh1 (sh, h) p)).
  { Exists vals head addc remc h'.
    unfold q_lock_pred'; entailer!.
    apply derives_refl. }
  { go_lower; entailer'. }
  { unfold q_lock_pred'; Intros.
    forward.
    { go_lower.
      rewrite cond_var_isptr; Intros; entailer'. }
    forward_call (addc0, lock, Tsh, sh, q_lock_pred t P p lock gsh2).
    { unfold q_lock_pred at 3; unfold q_lock_pred'; simpl.
      Exists vals0 head0 addc0 remc0 h'0.
      subst Frame; instantiate (1 := [field_at sh tqueue_t [StructField _lock] lock p;
        data_at Tsh t v e; malloc_token Tsh (sizeof t) e; ghost gsh1 (sh, h) p]); simpl.
      repeat rewrite sepcon_assoc; repeat (apply sepcon_derives; [apply derives_refl|]).
      entailer!.
      apply andp_right; [unfold fold_right; cancel | cancel]. }
    unfold q_lock_pred at 2; unfold q_lock_pred'; Intros vals1 head1 addc1 remc1 h'1.
    forward.
    Exists (vals1, head1, addc1, remc1, h'1).
    unfold q_lock_pred'; entailer!. }
  unfold q_lock_pred'; Intros.
  rewrite Int.signed_repr, Zlength_correct in HRE.
  freeze [0; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13] FR; forward.
  exploit (Z_mod_lt (head0 + Zlength vals0) MAX); [omega | intro].
  forward.
  forward.
  { go_lower.
    repeat apply andp_right; apply prop_right; auto.
    rewrite andb_false_intro2; simpl; auto. }
  forward.
  thaw FR.
  rewrite (cond_var_isptr _ remc0); Intros.
  forward.
  freeze [0; 1; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13] FR; forward_call (remc0, Tsh).
  thaw FR.
  rewrite upd_rotate; auto; try rewrite Zlength_complete; try rewrite Zlength_map; auto.
  rewrite Zminus_mod_idemp_l, Z.add_simpl_l, (Zmod_small (Zlength vals0));
    [|rewrite Zlength_correct; unfold MAX; omega].
  erewrite <- Zlength_map, upd_complete; [|rewrite Zlength_map, Zlength_correct; auto].
  gather_SEP 7 12.
  rewrite sepcon_comm; replace_SEP 0 (!!(list_incl h h'0) && ghost Tsh (Tsh, h'0) p).
  { go_lower.
    eapply derives_trans; [apply prop_and_same_derives, ghost_inj|].
    Intros; rewrite ghost_share_join; auto; entailer!. }
  Intros; apply hist_add with (e0 := QAdd e v).
  erewrite <- ghost_share_join with (h1 := h ++ [QAdd e v])(sh := sh); try eassumption.
  time forward_call (lock, sh, q_lock_pred t P p lock gsh2). (* 37s *)
  { lock_props.
    unfold q_lock_pred, q_lock_pred'.
    Exists (vals0 ++ [(e, v)]) head0 addc0 remc0 (h'0 ++ [QAdd e v]).
    rewrite data_at_isptr; Intros.
    rewrite map_app, Zlength_app, Zlength_cons, Zlength_nil.
    unfold sem_mod; simpl sem_binarith.
    unfold both_int; simpl force_val.
    rewrite andb_false_intro2; [|simpl; auto].
    simpl force_val.
    rewrite !add_repr, mods_repr; try computable.
    repeat match goal with H : _ /\ _ |- _ => destruct H end.
    simpl; apply andp_right.
    { apply prop_right; split; [rewrite Zlength_correct; unfold MAX; omega|].
      split; [omega|].
      apply consistent_snoc_add; auto. }
    rewrite Zplus_mod_idemp_l, Z.add_assoc, Zlength_map.
    repeat rewrite map_app; repeat rewrite sepcon_app; simpl.
    rewrite sem_cast_neutral_ptr; auto; simpl.
    rewrite sepcon_andp_prop', !sepcon_andp_prop, sepcon_andp_prop'; apply andp_right;
      [apply prop_right; auto | unfold fold_right at 1; cancel].
    { pose proof (Z_mod_lt (head0 + Zlength vals0) MAX).
      rewrite Zlength_map; split; try omega.
      transitivity MAX; simpl in *; [omega | unfold MAX; computable]. } }
  forward.
  { unfold lqueue; simpl; entailer!; auto. }
  { apply list_incl_app; auto. }
  { pose proof Int.min_signed_neg; split; [rewrite Zlength_correct; omega|].
    transitivity MAX; [auto | unfold MAX; computable]. }
Admitted.

Lemma body_q_remove : semax_body Vprog Gprog f_q_remove q_remove_spec.
Proof.
  unfold q_remove_spec, q_remove_spec'; start_function.
  destruct Q as (t, (P, h)).
  unfold lqueue; rewrite lock_inv_isptr; Intros.
  forward.
  forward_call (lock, sh, q_lock_pred t P p lock gsh2).
  unfold q_lock_pred at 2; unfold q_lock_pred'; Intros vals head addc remc h'.
  forward.
  rewrite data_at_isptr; Intros; rewrite isptr_offset_val_zero; auto.
  forward.
  forward_while (EX vals : list _, EX head : Z, EX addc : val, EX remc : val, EX h' : hist t, PROP ()
   LOCAL (temp _len (vint (Zlength vals)); temp _q p; temp _l lock; temp _tgt p)
   SEP (lock_inv sh lock (q_lock_pred t P p lock gsh2);
        q_lock_pred' t P p vals head addc remc lock gsh2 h';
        @field_at CompSpecs sh tqueue_t [StructField _lock] lock p; ghost gsh1 (sh, h) p)).
  { Exists vals head addc remc h'; unfold q_lock_pred'; entailer!. }
  { go_lower; entailer'. }
  { unfold q_lock_pred'; rewrite (cond_var_isptr _ remc0); Intros.
    forward.
    forward_call (remc0, lock, Tsh, sh, q_lock_pred t P p lock gsh2).
    { unfold q_lock_pred at 3; unfold q_lock_pred'; simpl.
      Exists vals0 head0 addc0 remc0 h'0.
      subst Frame; instantiate (1 := [field_at sh tqueue_t [StructField _lock] lock p;
        ghost gsh1 (sh, h) p]); simpl.
      repeat rewrite sepcon_assoc; repeat (apply sepcon_derives; [apply derives_refl|]).
      entailer!.
      apply andp_right; [Intros; entailer! | entailer!]. }
    unfold q_lock_pred at 2; unfold q_lock_pred'; Intros vals1 head1 addc1 remc1 h'1.
    forward.
    Exists (vals1, head1, addc1, remc1, h'1).
    unfold q_lock_pred'; entailer!. }
  unfold q_lock_pred'; Intros.
  assert (Zlength vals0 > 0).
  { rewrite Zlength_correct in *.
    destruct (length vals0); [|rewrite Nat2Z.inj_succ; omega].
    contradiction HRE; auto. }
  evar (R : mpred).
  replace_SEP 9 (!!(Forall isptr (map fst vals0)) && R); subst R.
  { go_lower; apply prop_and_same_derives, all_ptrs. }
  forward.
  forward.
  { go_lower; Intros.
    rewrite Znth_head; try rewrite Zlength_map; try omega.
    repeat apply andp_right; apply prop_right; auto.
    apply Forall_Znth; [rewrite Zlength_map; omega|].
    eapply Forall_impl; [|eauto].
    destruct a; auto. }
  forward.
  forward.
  { go_lower; simpl.
    repeat apply andp_right; apply prop_right; auto.
    rewrite andb_false_intro2; simpl; auto. }
  forward.
  rewrite cond_var_isptr; Intros.
  forward.
  freeze [0; 1; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12] FR; forward_call (addc0, Tsh).
  thaw FR.
  rewrite upd_rotate; try rewrite Zlength_complete; try rewrite Zlength_map; auto.
  rewrite Zminus_diag, Zmod_0_l.
  destruct vals0; [contradiction HRE; auto|].
  rewrite Zlength_cons in *.
  simpl; rewrite rotate_1; try rewrite Zlength_map; try omega.
  unfold sem_mod; simpl sem_binarith.
  unfold both_int; simpl force_val.
  rewrite andb_false_intro2; [|simpl; auto].
  simpl force_val.
  rewrite !add_repr, mods_repr; try computable.
  destruct p0 as (e, v).
  exploit (consistent_cons_rem(t := t)); eauto; intro.
  gather_SEP 8 11.
  rewrite sepcon_comm; replace_SEP 0 (!!(list_incl h h'0) && ghost Tsh (Tsh, h'0) p).
  { go_lower.
    eapply derives_trans; [apply prop_and_same_derives, ghost_inj|].
    Intros; rewrite ghost_share_join; auto; entailer!. }
  Intros; apply hist_add with (e0 := QRem e v).
  erewrite <- ghost_share_join with (h1 := h ++ [QRem e v])(sh := sh); try eassumption; try apply list_incl_app;
    auto.
  forward_call (lock, sh, q_lock_pred t P p lock gsh2).
  { lock_props.
    unfold q_lock_pred, q_lock_pred'; Exists vals0 ((head0 + 1) mod MAX) addc0 remc0 (h'0 ++ [QRem e v]).
    unfold Z.succ; rewrite sub_repr, Z.add_simpl_r, (Z.add_comm (Zlength vals0)), Z.add_assoc,
      Zplus_mod_idemp_l.
    unfold fold_right at 1; simpl; entailer!.
    apply Z_mod_lt; omega. }
  forward.
  Exists e v; unfold lqueue; simpl; entailer!; auto.
  rewrite Znth_head; auto; rewrite Zlength_cons, Zlength_map; omega.
  { split; try omega.
    transitivity MAX; [omega | unfold MAX; computable]. }
Qed.

Lemma body_q_tryremove : semax_body Vprog Gprog f_q_tryremove q_tryremove_spec.
Proof.
  unfold q_tryremove_spec, q_tryremove_spec'; start_function.
  destruct Q as (t, (P, h)).
  unfold lqueue; rewrite lock_inv_isptr; Intros.
  forward.
  forward_call (lock, sh, q_lock_pred t P p lock gsh2).
  unfold q_lock_pred at 2; unfold q_lock_pred'; Intros vals head addc remc h'.
  forward.
  rewrite data_at_isptr; Intros; rewrite isptr_offset_val_zero; auto.
  forward.
  forward_if (PROP (Zlength vals <> 0)
   LOCAL (temp _len (vint (Zlength vals)); temp _q p; temp _l lock; temp _tgt p)
   SEP (lock_inv sh lock (q_lock_pred t P p lock gsh2);
   data_at Tsh tqueue
     (rotate (complete MAX (map fst vals)) head MAX,
     (vint (Zlength vals), (vint head, (vint ((head + Zlength vals) mod MAX), (addc, remc))))) p;
   cond_var Tsh addc; cond_var Tsh remc; malloc_token Tsh (sizeof tqueue_t) p;
   malloc_token Tsh (sizeof tcond) addc; malloc_token Tsh (sizeof tcond) remc;
   malloc_token Tsh (sizeof tlock) lock; ghost gsh2 (Tsh, h') p;
   fold_right sepcon emp (map (fun x => let '(p, v) := x in
     !!(P v) && (data_at Tsh t v p * malloc_token Tsh (sizeof t) p)) vals);
   field_at sh tqueue_t [StructField _lock] lock p; ghost gsh1 (sh, h) p)).
  { forward_call (lock, sh, q_lock_pred t P p lock gsh2).
    { simpl; lock_props.
      unfold q_lock_pred, q_lock_pred'; Exists vals head addc remc h'; unfold fold_right at 1; simpl; entailer!. }
    forward.
    Exists (vint 0); entailer!.
    destruct (Memory.EqDec_val (vint 0) nullval); [|contradiction n; auto].
    unfold lqueue; simpl; entailer!. }
  { forward.
    entailer!.
    congruence. }
  Intros.
  assert (Zlength vals > 0).
  { rewrite Zlength_correct in *.
    destruct (length vals); [omega | rewrite Nat2Z.inj_succ; omega]. }
  evar (R : mpred).
  replace_SEP 9 (!!(Forall isptr (map fst vals)) && R); subst R.
  { go_lower; apply prop_and_same_derives, all_ptrs. }
  forward.
  forward.
  { go_lower; Intros.
    rewrite Znth_head; try rewrite Zlength_map; try omega.
    repeat apply andp_right; apply prop_right; auto.
    apply Forall_Znth; [rewrite Zlength_map; omega|].
    eapply Forall_impl; [|eauto].
    destruct a; auto. }
  forward.
  forward.
  { go_lower; simpl.
    repeat apply andp_right; apply prop_right; auto.
    rewrite andb_false_intro2; simpl; auto. }
  forward.
  rewrite cond_var_isptr; Intros.
  forward.
  freeze [0; 1; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12] FR; forward_call (addc, Tsh).
  thaw FR.
  rewrite upd_rotate; try rewrite Zlength_complete; try rewrite Zlength_map; auto.
  rewrite Zminus_diag, Zmod_0_l.
  destruct vals; [rewrite Zlength_nil in *; omega|].
  rewrite Zlength_cons in *.
  simpl; rewrite rotate_1; try rewrite Zlength_map; try omega.
  unfold sem_mod; simpl sem_binarith.
  unfold both_int; simpl force_val.
  rewrite andb_false_intro2; [|simpl; auto].
  simpl force_val.
  rewrite !add_repr, mods_repr; try computable.
  destruct p0 as (e, v).
  exploit (consistent_cons_rem(t := t)); eauto; intro.
  gather_SEP 8 11.
  rewrite sepcon_comm; replace_SEP 0 (!!(list_incl h h') && ghost Tsh (Tsh, h') p).
  { go_lower.
    eapply derives_trans; [apply prop_and_same_derives, ghost_inj|].
    Intros; rewrite ghost_share_join; auto; entailer!. }
  Intros; apply hist_add with (e0 := QRem e v).
  erewrite <- ghost_share_join with (h1 := h ++ [QRem e v])(sh := sh); try eassumption; try apply list_incl_app;
    auto.
  forward_call (lock, sh, q_lock_pred t P p lock gsh2).
  { lock_props.
    unfold q_lock_pred, q_lock_pred'; Exists vals ((head + 1) mod MAX) addc remc (h' ++ [QRem e v]).
    unfold Z.succ; rewrite sub_repr, Z.add_simpl_r, (Z.add_comm (Zlength vals)), Z.add_assoc,
      Zplus_mod_idemp_l.
    unfold fold_right at 1; simpl; entailer!.
    apply Z_mod_lt; omega. }
  forward.
  Exists e; entailer!.
  { rewrite Znth_head; auto; rewrite Zlength_cons, Zlength_map; omega. }
  destruct (Memory.EqDec_val e nullval).
  { rewrite data_at_isptr; Intros.
    subst; contradiction. }
  Exists v; unfold lqueue; simpl; entailer!; auto.
  { split; try omega.
    transitivity MAX; [omega | unfold MAX; computable]. }
Qed.

Lemma lock_precise : forall sh p lock (Hsh : readable_share sh),
  precise (field_at sh tqueue_t [StructField _lock] lock p).
Proof.
  intros.
  unfold field_at, at_offset; apply precise_andp2.
  rewrite data_at_rec_eq; simpl; auto.
Qed.

(*Lemma lock_struct : forall p, data_at_ Tsh (Tstruct _lock_t noattr) p |-- data_at_ Tsh tlock p.
Proof.
  intros.
  unfold data_at_, field_at_; unfold_field_at 1%nat; simpl.
  unfold field_at; simpl.
  rewrite field_compatible_cons; simpl; entailer.
Qed.

Lemma lock_struct_array : forall z p, data_at_ Tsh (tarray (Tstruct _lock_t noattr) z) p |--
  data_at_ Tsh (tarray tlock z) p.
Proof.
  intros.
  unfold data_at_, field_at_, field_at; simpl; entailer.
  unfold default_val, at_offset; simpl.
  do 2 rewrite data_at_rec_eq; simpl.
  unfold array_pred, aggregate_pred.array_pred, unfold_reptype; simpl; entailer.
  rewrite Z.sub_0_r; clear.
  forget (Z.to_nat z) as l; forget 0 as lo; revert lo; induction l; intros; simpl; auto.
  apply sepcon_derives.
  - unfold at_offset; rewrite data_at_rec_eq; simpl.
    unfold struct_pred, aggregate_pred.struct_pred, at_offset, withspacer; simpl; entailer.
  - eapply derives_trans; [apply aggregate_pred.rangespec_ext_derives |
      eapply derives_trans; [apply IHl | apply aggregate_pred.rangespec_ext_derives]]; simpl; intros;
      rewrite Znth_pos_cons; try omega; replace (i - lo - 1) with (i - Z.succ lo) by omega; auto.
Qed.*)

Lemma lqueue_share_join : forall t P sh1 sh2 sh p lock gsh1 gsh2 h1 h2
  (Hsh1 : readable_share sh1) (Hsh2 : readable_share sh2) (Hjoin : sepalg.join sh1 sh2 sh),
  lqueue sh1 t P p lock gsh1 gsh2 h1 * lqueue sh2 t P p lock gsh1 gsh2 h2 =
  lqueue sh t P p lock gsh1 gsh2 (h1 ++ h2).
Proof.
  intros; unfold lqueue; normalize.
  f_equal.
  - f_equal; apply prop_ext; tauto.
  - erewrite <- (field_at_share_join _ _ _ _ _ _ _ Hjoin), <- (lock_inv_share_join sh1 sh2 sh),
      <- (hist_share_join _ _ _ _ _ _ _ _ Hjoin); auto.
    rewrite <- !sepcon_assoc, !sepcon_assoc; f_equal.
    rewrite <- sepcon_assoc, sepcon_comm, sepcon_assoc; f_equal.
    rewrite sepcon_comm, sepcon_assoc; f_equal.
    rewrite sepcon_comm, sepcon_assoc; f_equal.
    rewrite sepcon_comm; reflexivity.
Qed.

Lemma lqueue_precise : forall lsh t P p lock gsh1 gsh2,
  precise (EX h : hist t, lqueue lsh t P p lock gsh1 gsh2 h).
Proof.
  intros; unfold lqueue.
  apply derives_precise' with (Q := field_at lsh tqueue_t [StructField conc_queue._lock] lock p *
    lock_inv lsh lock (q_lock_pred t P p lock gsh2) * EX f : share * hist t, ghost gsh1 f p).
  - entailer!.
    Exists (lsh, h); auto.
  - repeat apply precise_sepcon; auto.
    apply ghost_precise.
Qed.
Hint Resolve lqueue_precise.

Lemma lqueue_isptr : forall lsh t P p lock gsh1 gsh2 h, lqueue lsh t P p lock gsh1 gsh2 h =
  !!isptr p && lqueue lsh t P p lock gsh1 gsh2 h.
Proof.
  intros; eapply local_facts_isptr with (P := fun p => lqueue lsh t P p lock gsh1 gsh2 h); eauto.
  unfold lqueue; rewrite field_at_isptr; Intros; apply prop_right; auto.
Qed.