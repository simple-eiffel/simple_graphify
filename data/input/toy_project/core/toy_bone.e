note
	description: "A chewable bone"

class
	TOY_BONE

create
	make

feature {NONE} -- Initialization

	make
			-- Create an unchewed bone.
		do
			chew_count := 0
		ensure
			fresh: chew_count = 0
		end

feature -- Access

	chew_count: INTEGER
			-- Number of chews so far.

feature -- Basic operations

	chew
			-- Chew once.
		require
			not_worn_out: chew_count < 100
		do
			chew_count := chew_count + 1
		ensure
			chewed: chew_count = old chew_count + 1
		end

invariant
	count_non_negative: chew_count >= 0

end
