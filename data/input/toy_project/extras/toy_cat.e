note
	description: "A cat that ignores bones"

class
	TOY_CAT

inherit
	TOY_ANIMAL

create
	make

feature {NONE} -- Initialization

	make
			-- Cats are never hungry (they say).
		do
			is_hungry := False
		end

feature -- Access

	name: STRING = "cat"
			-- <Precursor>

	sound: STRING = "meow"
			-- <Precursor>

feature -- Basic operations

	inspect_bone (a_bone: TOY_BONE): BOOLEAN
			-- Would this cat deign to touch `a_bone`? (No.)
		require
			bone_attached: a_bone /= Void
		do
			Result := False
		ensure
			always_no: not Result
		end

end
