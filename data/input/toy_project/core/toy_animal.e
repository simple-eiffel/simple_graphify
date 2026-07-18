note
	description: "Deferred animal abstraction for the toy fixture"

deferred class
	TOY_ANIMAL

feature -- Access

	name: STRING
			-- Animal name.
		deferred
		ensure
			name_not_void: Result /= Void
		end

	sound: STRING
			-- NOTE: every animal must define its own sound.
		deferred
		ensure
			sound_not_empty: not Result.is_empty
		end

feature -- Status report

	is_hungry: BOOLEAN
			-- Does the animal want food?

feature -- Basic operations

	feed
			-- Feed the animal.
		require
			hungry: is_hungry
		do
			is_hungry := False
		ensure
			fed: not is_hungry
		end

end
