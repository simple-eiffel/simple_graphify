note
	description: "A dog that buries bones"

class
	TOY_DOG

inherit
	TOY_ANIMAL

create
	make

feature {NONE} -- Initialization

	make
			-- WHY: dogs start hungry so feeding paths get exercised.
		do
			is_hungry := True
			create {TOY_BONE} favorite_bone.make
		end

feature -- Access

	name: STRING = "dog"
			-- <Precursor>

	sound: STRING = "woof"
			-- <Precursor>

	favorite_bone: TOY_BONE
			-- The bone this dog is carrying.
			-- Unlike TOY_CAT, dogs always carry one.

invariant
	bone_attached: favorite_bone /= Void

end
