VAR apata_trap_stage = 0
VAR erida_trap_stage = 0
- (conversation)
Да?	# actor:female 
+	{apata_trap_stage > 2} [Ксения, что здесь написано?]
	Ксения, что здесь написано?	# actor:player # voiceover:115_Xenia_chto_zdes_napisano.ogg
	На стене написано: «Раскрой обман и восстанови истину». На пьедестале где статуэтка со сферой: «Театр», рядом – «Астрономия» и под статуэткой с маской – «История».	# actor:female # voiceover:214_na_stene_napisano.ogg
	+ +	[Ты знаешь что-то об этих статуэтках?]
		Ты знаешь что-то об этих статуэтках?	# actor:player # voiceover:117_ty_znaesh_chto_to.ogg
		Похоже статуэтки изображают муз. Всего их двенадцать, но здесь только три. Покровительница театра – Мельпомена, астрономии – Урания, истории – Клио. Точно не помню у кого какие должны быть атрибуты, но мне кажется музы стоят не на своих пьедесталах.	# actor:female	# voiceover:215_pohozhe_statuetki_izobrazhayut.ogg # finalizer 
	+ +	[Ясно.]
		Ясно.	# actor:player # voiceover:116_yasno.ogg	# finalizer
+	{erida_trap_stage > 1} [Ксения, есть миф об Эриде?]
	Ксения, есть миф об Эриде?	# actor:player # voiceover:241_Xenia_est_mif_ob_Eride.ogg
	Эрида – богиня раздора. Она подбросила Афродите -- богине красоты, Гере -- верховной богине и Афине -- богине справедливой войны яблоко с надписью: «callisti», то есть «прекраснейшей». Богини тут же принялись спорить, кому предназначается это яблоко.	# actor:female # voiceover:287_Erida_boginya_razdora.ogg	# finalizer
+	[Давай позже поговорим, нельзя отвлекаться.]
	Давай позже поговорим, нельзя отвлекаться. # finalizer
-	-> conversation