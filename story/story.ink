// Author in Inky. Recompile to story/story.json (see README).
// Runtime uses story.json; keep knots in sync.

=== archives_intro ===
You wake on cold linoleum. Redacted files tower above you.
Your head is empty of why you're here.
-> DONE

=== archives_tutorial ===
Maybe you should look around. Things here might respond if you click them.
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
// TAG: trigger:scp1_encounter on line 2 in JSON
Something cold brushes the back of your neck.
-> scp1_encounter

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

=== scp1_encounter ===
{ missing_researcher_id:
  A shape in the corner. It tilts toward you, curious—and measuring.
- else:
  A shape in the corner. It hesitates at your badge name.
}
* [Stay calm. Speak softly.]
  -> scp1_befriend
* [Back away quickly.]
  -> scp1_hostile
* [Offer the notes you gathered] { paper_left_read or paper_right_read }
  -> scp1_befriend

=== scp1_befriend ===
It stills. For now, you think it understands.
-> DONE

=== scp1_hostile ===
It recoils—or bristles. You'll hear from it again, and not kindly.
-> DONE
