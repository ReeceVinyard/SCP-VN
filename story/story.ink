// Author in Inky. Recompile to story/story.json (see README).
// Runtime uses story.json; keep knots in sync.

=== archives_intro ===
You wake on cold linoleum. Redacted files tower above you.
Your head is empty of why you're here.
-> DONE

=== archives_tutorial ===
Clearance registered. When you're ready, head to the security door.
-> DONE

=== archives_find_id ===
Researcher ID. The photo might be you—the name field is smudged.
-> DONE

=== archives_find_keycard ===
Level-2 keycard. Still warm, like someone left in a hurry.
-> DONE

=== archives_desk_empty ===
The drawer is empty.
-> DONE

=== archives_locker_empty ===
Nothing left in the locker.
-> DONE

=== archives_door_locked ===
Security door. You'll need your keycard.
-> DONE

=== archives_need_name ===
The system won't let you badge out until your credentials match a registered name.
-> DONE

=== archives_exit ===
The reader chirps. The door unlatches.
-> DONE

=== archives_shelf_flavor ===
Rows of redacted binders. Someone circled a date—yesterday.
-> DONE

=== hall_enter ===
The corridor is littered with papers. Footsteps echo from nowhere.
-> DONE

=== paper_left ===
A cafeteria memo: "All break room microwaves replaced." Useless. Slightly comforting.
-> DONE

=== paper_left_done ===
You've already read this memo.
-> DONE

=== paper_middle ===
Incident follow-up: Subject interaction logged—appendix missing—
You find form EH-14 beneath the page—dense, legible if you take time to read it.
// Document reader opens from exploration_map; Chase starts after you finish reading.
-> DONE

=== paper_middle_done ===
Scorch marks where the paper lay. Whatever happened, it left.
-> DONE

=== paper_right ===
A personnel roster with every name blacked out except one: yours—or someone like you.
-> DONE

=== paper_right_done ===
The roster is gone. Only ash.
-> DONE

=== hall_return_archives ===
The archives feel safer than whatever is out here.
-> DONE

=== chase_arrival ===
Chase appears—haggard, armed, out of breath. You are both surprised.
-> chase_evacuation

=== chase_evacuation ===
Chase: Wait—what? Why are you still here? Evac started thirty minutes ago!
* [Tell him you woke with no memory.]
    -> chase_amnesia_response
* [Blame a lost keycard in the Archives.]
    -> chase_lie_response

=== chase_amnesia_response ===
You confess the blank in your memory. Chase believes you—something failed in the labs.
-> chase_guide_gentle

=== chase_lie_response ===
You lie about the keycard. Chase scolds you—breach, dead staff, move now.
-> chase_guide_harsh

=== chase_guide_gentle ===
Chase explains the facility is unsafe and points to the open forward door.
-> DONE

=== chase_guide_harsh ===
Chase warns you harshly and orders you through the open door.
-> DONE

=== hall_forward_enter ===
You follow Chase into the next wing.
-> DONE

// SCP encounter reserved for after the Chase sequence (see story.json).

=== scp1_encounter ===
(Reserved.)
-> DONE

=== scp1_befriend ===
(Reserved.)
-> DONE

=== scp1_hostile ===
(Reserved.)
-> DONE
