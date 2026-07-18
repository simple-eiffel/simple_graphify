note
	description: "Registry holding all animals in the toy world"

class
	TOY_REGISTRY

create
	make

feature {NONE} -- Initialization

	make
			-- TODO: support more species than dogs and cats.
		local
			l_dog: TOY_DOG
			l_cat: TOY_CAT
		do
			create animals.make (4)
			create l_dog.make
			animals.extend (l_dog)
			create l_cat.make
			animals.extend (l_cat)
		ensure
			populated: animals.count = 2
		end

feature -- Access

	animals: ARRAYED_LIST [TOY_ANIMAL]
			-- All registered animals.

	count: INTEGER
			-- Number of animals.
		do
			Result := animals.count
		ensure
			definition: Result = animals.count
		end

invariant
	animals_attached: animals /= Void

end
