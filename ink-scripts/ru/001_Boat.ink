VAR relationship_female = 0
*	[А где лодка?]
	~ relationship_female = relationship_female + 1
	А где лодка?	# actor:player
	Не знаю. Наверное ты забыл её привязать и когда начался прилив лодку унесло в море. А ты чего прибежал так быстро? Поверил, что я заберу лодку и оставлю тебя на острове?	# actor:female
	Побоялся что поплывёшь одна и тебя унесёт в открытое море.	# actor:player
	Понятно. Жаль, что лодка уплыла.	# actor:female
	Ладно, мне нужно проверить одну догадку. Будь здесь, через пару часов я вернусь и мы вместе дождёмся парома.	# actor:player
	Ну вот, теперь придётся стоять на пляже, а ведь здесь даже пня нет.	# actor:female