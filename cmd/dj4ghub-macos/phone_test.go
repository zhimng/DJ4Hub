package main

import (
	"testing"
)

func TestVoiceCallsExcludeData(t *testing.T) {
	calls := parseVoiceCalls("+CLCC: 1,1,0,1,0,\"\",128\r\n+CLCC: 3,0,0,0,0,\"123\",129,\"Service\"\r\n+CLCC: bad\r\n")
	if len(calls) != 1 || calls[0].ID != 3 || calls[0].Number != "123" {
		t.Fatalf("unexpected voice calls: %+v", calls)
	}
}

func TestIncomingActionRejectsStaleOrAmbiguousCalls(t *testing.T) {
	for _, state := range []int{4, 5} {
		if !matchesIncomingAction([]voiceCall{{ID: 1, State: state}}, 1, "answer") {
			t.Fatal("ringing call rejected")
		}
	}
	for _, calls := range [][]voiceCall{nil, {{ID: 2, State: 4}}, {{ID: 1, State: 0}}, {{ID: 1, State: 4}, {ID: 2, State: 0}}} {
		if matchesIncomingAction(calls, 1, "hangup") {
			t.Fatal("stale or ambiguous action accepted")
		}
	}
	if matchesIncomingAction([]voiceCall{{ID: 1, State: 4}}, 1, "dial") {
		t.Fatal("unexpected action accepted")
	}
}
