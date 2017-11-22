//add master tune to this and cv keyboard
//LET'S MAKE THE NUMBER OF SEQUENCES FUCKING DEEEEEEEEEEEP! later...

//gotta get sustain time on an array!!!!
//individual envelope level controls?

//get a delay where I can change the time from the ARC!!!!
//I think another grid will come in handy here...but for so few parameters????
//won't be so few with multiple sequences going
//should loop restart on moving loop offset?

//get all parameters to initalize correctly
//(
//a = Environment.make{
(
//client side variables
~numSeq = 2;
~seqFoc = 0;

~noteData = Array.fill2D(~numSeq, 16, 0);
~noteSelectionHeld = Array.fill2D(~numSeq, 1);
for(0, (~numSeq - 1), {arg i;
	~noteSelectionHeld[i] = [0, 0, 0];
}); //first element is status, second is x location, third is y location
~noteIndex = Array.fill2D(~numSeq, 16, 5);

~durData = Array.fill2D(~numSeq, 16, 1);
~durationSelectionHeld = Array.fill2D(~numSeq, 1);
for(0, (~numSeq - 1), {arg i;
	~durationSelectionHeld[i] = [0, 0, 5];
}); //first element is status, second is location, third is hard coded default index
~durationIndex = Array.fill2D(~numSeq, 16, 5); //hard coded to the duration value where 1 is

~octaveData = Array.fill2D(~numSeq, 16, 0);
~octaveSelectionHeld = Array.fill2D(~numSeq, 1);
for(0, (~numSeq - 1), {arg i;
	~octaveSelectionHeld[i] = [0, 0];
}); //first element is status, second is location
~octaveIndex = Array.fill2D(~numSeq, 16, 3); //hard coded to octave 1

//variables for counting steps
~loopOffsetHeld = Array.fill2D(~numSeq, 1);
for(0, (~numSeq - 1), {arg i;
	~loopOffsetHeld[i] = [0, 0];
}); //first element is status, second is location
~lengthHeld = Array.fill2D(2, 1);
for(0, (~numSeq - 1), {arg i;
	~lengthHeld[i] = [0, 0, 4]; //first element is status, second is location, third is value
});

~count = Array.fill(~numSeq, -1);
~length = Array.fill(~numSeq, 4);
~loopOffset = Array.fill(~numSeq, 0);

~sustainTime = 0.5;

~grid = MonoM.new("/monome", 0);
~arc = Arc.new("/monome", 0);
~grid64 = MonoM.new("/monome", 0);

~gridLeds = Array.fill2D(~numSeq, 128, 0);
~grid64Leds = Array.fill(64, 0);

~arcSelectionLeft = [0, 0]; //left is holding status (one is held 0 is not) right is selection index
~arcSelectionRight = [0, 1];
~arcLedsSaved = [[4, 0], [7, 0]]; //this is misleading because it's grid leds not arc leds

~tempo = 120;
~clock = TempoClock(~tempo/60);
//functions for updating variables from ArcParameters
~susFunc = {arg i;
	~sustainTime = i;
};
~clockFunc = {arg i;
	~tempo = i;
	~clock.tempo = i / 60;
};
~initCvSeq = nil;
//osc functions for grid and arc
OSCFunc.newMatching( //main 128 grid
	{ arg message, time, addr, recvPort;
		var semi = [(0.1/12) * 11, (0.1/12) * 8.9, (0.1/12) * 6.9, (0.1/12) * 3.85, (0.1/12) * 2, (0.1/12) * 0];
		//var semi = [200, 180, 160, 140, 120, 100];
		var durations = [0.125, 0.25, 0.375, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 3, 4, 6, 8, 12, 16]; // this should simply be better
		var octaves = [0.3, 0.2, 0.1, 0, -0.1, -0.2];
		//var octaves = [8, 4, 2, 1, 0.5, 0.25];
		var loopRowLeds = {
			//loop row leds
			for(0, 15, {arg x;
				~gridLeds[~seqFoc][x + (7 * 16)] = 0;
			});
			for(~loopOffset[~seqFoc], ~loopOffset[~seqFoc] + (~length[~seqFoc] - 1), {arg i;
				~gridLeds[~seqFoc][(i % 16) + (7 * 16)] = 10;
			});
			~updateGridLeds.value;
		};
		postln(addr);
		if(message[2] < 6, { //top six rows
			switch(~octaveSelectionHeld[~seqFoc][0], 0, {
				//holding note selection to select duration
				switch(message[3], 1, {
					~durationSelectionHeld [~seqFoc]= [1, message[1], ~durationIndex[~seqFoc][message[1]]];
					~noteSelectionHeld [~seqFoc]= [1, message[1], message[2]];
					postln("new note is pre-selected");
					postln("duration selection is on");
					//display duration leds
					for(0, 15, {arg x;
						if(~durationIndex[~seqFoc][message[1]] == x, {
							~gridLeds[~seqFoc][x + (6 * 16)] = 10;
						}, {
							if(x.odd,{
								~gridLeds[~seqFoc][x + (6 * 16)] = 3;
							}, {
								~gridLeds[~seqFoc][x + (6 * 16)] = 0;
							});
						});
					});
					~updateGridLeds.value;
				}, 0, {
					//release duration selection held...stored value gets passed to acting value
					~durData[~seqFoc][~durationSelectionHeld[~seqFoc][1]] = durations[~durationSelectionHeld[~seqFoc][2]];
					//postln("duration" + ~durationSelectionHeld[~seqFoc][1] + "=" + durations[~durationSelectionHeld[~seqFoc][2]]);
					//update note selection
					if(message[1] == ~noteSelectionHeld[~seqFoc][1], {
						~noteData[~seqFoc][~noteSelectionHeld[~seqFoc][1]] = semi[~noteSelectionHeld[~seqFoc][2]];
						~noteIndex[~seqFoc][~noteSelectionHeld[~seqFoc][1]] = ~noteSelectionHeld[~seqFoc][2]; //this could cause a runtime bug I bet!
						postln("note" + message[1] + "=" + ~noteSelectionHeld[~seqFoc][2]);
					});
					//update note selection led
					for(0, 6, {arg y;
						~gridLeds[~seqFoc][message[1] + (y * 16)] = 0;
					});
					~gridLeds[~seqFoc][message[1] + (message[2] * 16)] = 15;
					if(~durationSelectionHeld[~seqFoc][1] == message[1], {
						~durationSelectionHeld[~seqFoc][0] = 0;
						postln("duration selection is off");
						for(0, 15, {arg x;
							~gridLeds[~seqFoc][x + (6 * 16)] = 0;
						});
						~updateGridLeds.value;
					});
				});
			}, 1, {
				//octave selection
				if(message[1] == ~octaveSelectionHeld[~seqFoc][1], {
					~octaveData[~seqFoc][~octaveSelectionHeld[~seqFoc][1]] = octaves[message[2]];
					~octaveIndex[~seqFoc][~octaveSelectionHeld[~seqFoc][1]] = message[2];
					postln("octave" + ~octaveSelectionHeld[~seqFoc][1] + "=" + ~octaveData[~seqFoc][~octaveSelectionHeld[~seqFoc][1]]);
					//update octave led
					for(0, 5, {arg y;
						if(~octaveIndex[~seqFoc][~octaveSelectionHeld[~seqFoc][1]] == y, {
							~gridLeds[~seqFoc][~octaveSelectionHeld[~seqFoc][1] + (y * 16)] = 7;
						}, {
							~gridLeds[~seqFoc][~octaveSelectionHeld[~seqFoc][1] + (y * 16)] = 0;
						});
					});
					~updateGridLeds.value;
				});
			});
		}, { //bottom two rows
			switch(message[2], 6, { //octave selection/duration row
				switch(message[3], 1, {
					switch(~durationSelectionHeld[~seqFoc][0], 0, {
						postln("you're about to select your octave");
						~octaveSelectionHeld[~seqFoc][0] = 1;
						~octaveSelectionHeld[~seqFoc][1] = message[1]; //location of octave selection on x-axis
						for(0, 5, {arg y;
							if(~octaveIndex[~seqFoc][message[1]] == y, {
								~gridLeds[~seqFoc][~octaveSelectionHeld[~seqFoc][1] + (y * 16)] = 7;
							}, {
								~gridLeds[~seqFoc][~octaveSelectionHeld[~seqFoc][1] + (y * 16)] = 0;
							});
						});
						~updateGridLeds.value;
					}, 1, {
						~durationSelectionHeld[~seqFoc][2] = message[1];
						~durationIndex[~seqFoc][~durationSelectionHeld[~seqFoc][1]] = message[1];
						//update duration display led
						for(0, 15, {arg x;
							if(~durationIndex[~seqFoc][~durationSelectionHeld[~seqFoc][1]] == x, {
								~gridLeds[~seqFoc][x + (6 * 16)] = 10;
							}, {
								if(x.odd,{
									~gridLeds[~seqFoc][x + (6 * 16)] = 3;
								}, {
									~gridLeds[~seqFoc][x + (6 * 16)] = 0;
								});
							});
						});
						~updateGridLeds.value;
					});
				}, 0, {
					switch(~durationSelectionHeld[~seqFoc][0], 0, {
						//update note selection led after releasing octave selection
						for(0, 6, {arg y;
							if(~noteIndex[~seqFoc][message[1]] == y, {
								~gridLeds[~seqFoc][message[1] + (y * 16)] = 15;
							}, {
								~gridLeds[~seqFoc][message[1] + (y * 16)] = 0;
							});
						});
						~updateGridLeds.value;
						postln("you're not selecting your octave anymore");
						~octaveSelectionHeld[~seqFoc][0] = 0;
					}, 1, {
					});
				});
			}, 7, { //loop offset and length[~seqFoc] row
				switch(message[3], 1, {
					switch(~loopOffsetHeld[~seqFoc][0], 0, {
						~loopOffsetHeld [~seqFoc]= [1, message[1]];
						postln("loop offset is held");
						//~loopRowLeds.value;
					}, 1, { //set length[~seqFoc]
						if(message[1] < ~loopOffsetHeld[~seqFoc][1], { //for wrapping a length around the end of the grid
							~lengthHeld[~seqFoc][2] = (16 - ~loopOffsetHeld[~seqFoc][1]) + (message[1] + 1);
						}, {
							~lengthHeld [~seqFoc]= [1, message[1], (message[1] + 1) - ~loopOffsetHeld[~seqFoc][1]]; //setting length without wrapping around the end of the grid
						});

					});
				}, 0, {
					switch(message[1], ~loopOffsetHeld[~seqFoc][1],{
						~loopOffsetHeld[~seqFoc][0] = 0; //watch out...i had troubles with arrays like this
						~loopOffset[~seqFoc] = ~loopOffsetHeld[~seqFoc][1];
						~length[~seqFoc] = ~lengthHeld[~seqFoc][2];
						postln("loop offset is not held");
					}, ~lengthHeld[~seqFoc][1], {
						postln("loop length will equal =" + ~lengthHeld[~seqFoc][2]);
					});
					loopRowLeds.value;
				});
			});
		});
}, "/monome/grid/key", NetAddr("127.0.0.1", 16139));
OSCFunc.newMatching( //64 grid
	{ arg message, time, addr, recvPort;
		//postln(message[1] + "" + message[2] + "" + message[3]);
		if(message[1] >= 4, { //arc selection columns
			var selrow = [4, 5, 6, 7];
			var arcSelLeds = {arg row, col, side; //side = 0 for left encoders, side = 1 for right encoders
				var clear = {
					for(0, 7, {arg y;
						for(selrow[0], selrow[3], {arg x;
							~grid64Leds[x + (y * 8)] = 0;
						});
					});
				};
				var leds = {
					~grid64Leds[~arcLedsSaved[0][0] + (~arcLedsSaved[0][1] * 8)] = 15;
					~grid64Leds[(~arcLedsSaved[0][0] + 1) + (~arcLedsSaved[0][1] * 8)] = 15;
					~grid64Leds[~arcLedsSaved[1][0] + (~arcLedsSaved[1][1] * 8)] = 7;
					~grid64Leds[(~arcLedsSaved[1][0] - 1) + (~arcLedsSaved[1][1] * 8)] = 7;
					~updateGrid64Leds.value;
				};
				switch(side, 0, {
					~arcLedsSaved[0] = [selrow[row], col];
					clear.value();
					leds.value();
				}, 1, {
					~arcLedsSaved[1] = [selrow[row], col];
					clear.value();
					leds.value();
				});
			};
			var leftenc = {arg row, col;
				var pairBound = {arg offset; // check to make sure there is a parameter to go to
					var index = offset + (message[2] * 2);
					if(index < ~pairs.size, {
						~arcSelectionLeft[1] = index;
						postln("arc selection left =" + ~arcSelectionLeft[1]);
						~updateArcLeds.value(0, ~pairs[~arcSelectionLeft[1]][0].arcLedValue);
						~updateArcLeds.value(1, ~pairs[~arcSelectionLeft[1]][1].arcLedValue);
						postln("arc selection left is held");
						arcSelLeds.value(row, col, 0);
					});
				};
				switch(message[3], 1, {
					if(~arcSelectionLeft[0] == 0, {
						~arcSelectionLeft[0] = 1;
						switch(row, 0, {
							pairBound.value(0);
						}, 2, {
							pairBound.value(1);
						});
					});
				}, 0, {
					if(~arcSelectionLeft[0] == 1, {
						~arcSelectionLeft[0] = 0;
						postln("arc selection left is not held");
					});
				});
			};
			var rightenc = {arg row, col;
				var pairBound = {arg offset; // check to make sure there is a parameter to go to
					var index = offset + (message[2] * 2);
					if(index < ~pairs.size, {
						~arcSelectionRight[1] = index;
						postln("arc selection right =" + ~arcSelectionRight[1]);
						~updateArcLeds.value(2, ~pairs[~arcSelectionRight[1]][0].arcLedValue);
						~updateArcLeds.value(3, ~pairs[~arcSelectionRight[1]][1].arcLedValue);
						postln("arc selection right is held");
						arcSelLeds.value(row, col, 1);
					});
				};
				switch(message[3], 1, {
					if(~arcSelectionRight[0] == 0, {
						~arcSelectionRight[0] = 1;
						switch(row, 1, {
							pairBound.value(0);
						}, 3, {
							pairBound.value(1);
						});
					});
				}, 0, {
					if(~arcSelectionRight[0] == 1, {
						~arcSelectionRight[0] = 0;
						postln("arc selection right is not held");
					});
				});
			};
			switch(message[1], selrow[0],{
				leftenc.value(0, message[2]);
			}, selrow[1], {
				rightenc.value(1, message[2]);
			}, selrow[2], {
				leftenc.value(2, message[2]);
			}, selrow[3], {
				rightenc.value(3, message[2]);
			});
		}, {
			switch(message[1], 0, {
				~seqFoc = 0;
				for(0, 7, {arg y;
					for(0, 1, {arg x;
					~grid64Leds[x + (y * 8)] = 0;
				});
				});
				~grid64Leds[0 + (0 * 8)] = 15;
				~updateGrid64Leds.value;
			}, 1, {
				~seqFoc = 1;
				for(0, 7, {arg y;
					for(0, 1, {arg x;
					~grid64Leds[x + (y * 8)] = 0;
				});
				});
				~grid64Leds[1 + (0 * 8)] = 15;
				~updateGrid64Leds.value;
			});
			~updateGridLeds.value;
		};
		);
}, "/monome/grid/key", NetAddr("127.0.0.1", 18279));

OSCFunc.newMatching( //arc
	{ arg message, time, addr, recvPort;
		var arcFunctions = {arg name, messageOne, messageTwo, ledLevel = 15;
			name.change(messageTwo);
			name.sendChange;
			~updateArcLeds.value(messageOne, name.arcLedValue, ledLevel);
		};
		switch(message[1], 0, {
			arcFunctions.value(~pairs[~arcSelectionLeft[1]][0], 0, message[2]);
		}, 1, {
			arcFunctions.value(~pairs[~arcSelectionLeft[1]][1], 1, message[2]);
		}, 2, {
			arcFunctions.value(~pairs[~arcSelectionRight[1]][0], 2, message[2]);
		}, 3, {
			arcFunctions.value(~pairs[~arcSelectionRight[1]][1], 3, message[2]);
		});
}, "/monome/enc/delta");
~updateGridLeds = {
	var x, y, tempGridLedsLeft, tempGridLedsRight, gridWidth;
	gridWidth = 16;
	tempGridLedsLeft = Array.fill(64, 0);
	tempGridLedsRight = Array.fill(64, 0);

	for(0, 7, { arg y;
		for(0, 15, { arg x;
			var index16 = x + (y * gridWidth);
			var index8 = x + (y * 8);
			var playPosition = (~count[~seqFoc] + ~loopOffset[~seqFoc]) % 16;
			if(x < 8, {
				//extra stuff for the playhead indicator
				if((x == (playPosition)) && (y < 7), {
					if(~gridLeds[~seqFoc][index16] > 0, {
						tempGridLedsLeft[index8] = ~gridLeds[~seqFoc][index16];
					}, {
						tempGridLedsLeft[index8] = 2;
					});
				}, {
					tempGridLedsLeft[index8] = ~gridLeds[~seqFoc][index16];
				});
			}, {
				if((x == (playPosition)) && (y < 7), {
					if(~gridLeds[~seqFoc][index16] > 0, {
						tempGridLedsRight[index8 - 8] = ~gridLeds[~seqFoc][index16];
					}, {
						tempGridLedsRight[index8 - 8] = 2;
					});
				}, {
					tempGridLedsRight[index8 - 8] = ~gridLeds[~seqFoc][index16];
				});
			});
		});
	});
	~grid.levmap(0, 0, tempGridLedsLeft);
	~grid.levmap(8, 0, tempGridLedsRight);
};
~updateGrid64Leds = {
	~grid64.levmap(0, 0, ~grid64Leds);
};
~updateArcLeds = {arg encoderNumber, ledValue, ledLevel = 15;
	var encoderTemporaryArray = Array.fill(64, { arg index;
		if(index <= ledValue, { ledLevel }, { 0 });
	});
	~arc.ringmap(encoderNumber, encoderTemporaryArray);

};

s.waitForBoot({
	~grid.usePort(16139);
	~arc.usePort(16159);
	~grid64.usePort(18279);

	s.makeBundle(nil, {
		~cvSynths = Group.new;
		s.sync;
		SynthDef("CVout", {arg mul = 0.1, add = 0.1, gate = 0, attack = 0.001, release = 0.1, freqScale = 1,
			pitchOut = 0, envOut = 1, freqOut = 2, amp = 0.2;
			var envshape = Env([0, amp, 0], [attack, release], releaseNode: 1);
			var envgen = EnvGen.ar(envshape, gate);
			var pitch = SinOsc.ar(0.2, 0, mul, add);
			//var pitch2 = SinOsc.ar(0.2, 0, mul, freq);

			Out.ar(pitchOut, pitch);
			Out.ar(envOut, envgen);
			//Out.ar(2, pitch * freqScale);
			Out.ar(freqOut, pitch * freqScale);
			/* for synthdef
			var pitch = PulseDPW.ar(add, 0.5, mul, 0);
			Out.ar([0, 1], pitch);
			*/
		}).add;
		s.sync;
		~cv1 = Synth("CVout", [\pitchOut, 0, \envOut, 1, \freqOut, 2, \freq, 0, \mul, 0, \amp, 0.4], ~cvSynths);
		~cv2 = Synth("CVout", [\pitchOut, 3, \envOut, 4, \freqOut, 5, \freq, 0, \mul, 0, \amp, 1], ~cvSynths);
		//f = Synth("CVout", [\freq, 0, \mul, 0.1]); // for synthdef
		SynthDef("Delay", {arg delayTime = 1, decayTime = 1, delayLevel = 0;
			var input = SoundIn.ar(0, 1);
			var filter = DFM1.ar(input, 300, 0, type: 1);
			var delay = CombC.ar(filter, 4, Lag.kr(delayTime, 0.2), decayTime, delayLevel);
			Out.ar(7, input + delay);
		}).add;
		s.sync;
		~delay = Synth("Delay");
		s.sync;
		~pairs = [ //changes accessable by the arc
			[ArcParameter.new("Attack", 0.001, 10, 25, 2, 0.001, ~cvSynths, \attack, 0), ArcParameter.new("Release", 0.001, 10, 25, 2, 0.001, ~cvSynths, \release, 0)], [ArcParameter.new("Sustain Time", 0.001, 0.95, 100, 2, 0.1, ~susFunc, \nothing, -1), ArcParameter.new("Tempo", 10, 600, 5, 2, ~tempo, ~clockFunc, \nothing, -1)],

			[ArcParameter.new("Delay Time", 0.01, 3, 50, 2, 1, ~delay, \delayTime, 0), ArcParameter.new("Delay Feedback", 0.01, 40, 25, 2, 1, ~delay, \decayTime, 0)], [ArcParameter.new("Delay Level", 0, 1, 50, 2, 0, ~delay, \delayLevel, 0), ArcParameter.new("Cutoff Freq Scale", 0, 1, 100, 2, 1, ~cvSynths, \freqScale, 0)]
		];
	});

	~cvTask1 = Task({ //~seqFoc is subsituted for hard allocation here
		var time;

		loop{
			var seq = 0;
			var position;
			~count[seq] = (~count[seq] + 1) % ~length[seq];
			position = (~count[seq] + ~loopOffset[seq]) % 16;
			time = ~durData[seq][position] / (~tempo/60); //adjusting for synthdef in seconds
			~cv1.set(\add, (~noteData[seq][position]) + ~octaveData[seq][position], \gate, 1);
			//update location leds
			~updateGridLeds.value;
			//~clock.clear; //IF THERE ARE TIMING PROBLEMS GET RID OF THIS!!!
			~clock.sched(time * ~sustainTime, //WHAT ABOUT SUSTAIN TIME!!!!!!!!!!!??????????
				{
					~cv1.set(\gate, 0);
			});
			time.yield;
		};
	});
	~cvTask2 = Task({ //~seqFoc is subsituted for hard allocation here
		var time;

		loop{
			var seq = 1;
			var position;
			~count[seq] = (~count[seq] + 1) % ~length[seq];
			position = (~count[seq] + ~loopOffset[seq]) % 16;
			time = ~durData[seq][position] / (~tempo/60); //adjusting for synthdef in seconds
			~cv2.set(\add, (~noteData[seq][position]) + ~octaveData[seq][position], \gate, 1); //~seqFoc is subsituted for hard allocation here
			//update location leds
			~updateGridLeds.value;
			//~clock.clear; //IF THERE ARE TIMING PROBLEMS GET RID OF THIS!!!
			~clock.sched(time * ~sustainTime,
				{
					~cv2.set(\gate, 0);
			});
			time.yield;
		};
	});
	~initCvSeq = {
		var def64leds = [15, 0, 0, 0, 15, 15, 7, 7];
		~updateArcLeds.value(0, ~pairs[0][0].arcLedValue);
		~updateArcLeds.value(1, ~pairs[0][1].arcLedValue);
		~updateArcLeds.value(2, ~pairs[1][0].arcLedValue);
		~updateArcLeds.value(3, ~pairs[1][1].arcLedValue);
		~cvTask1.play(~clock);
		~cvTask2.play(~clock);
		//initialize loop row leds
		for(0, (~numSeq - 1), {arg i;
			for(0, 15, {arg x;
				~gridLeds[i][x + (5 * 16)] = 15;
				if((x >= ~loopOffset[~seqFoc]) && (x < (~loopOffset[~seqFoc] + ~length[~seqFoc])), {
					~gridLeds[i][x + (7 * 16)] = 10;
				}, {
					~gridLeds[i][x + (7 * 16)] = 0;
				});
			});
		});
		//initialze grid leds
		~updateGridLeds.value;
		for(0, 7, {arg x;
			~grid64Leds[x + (0 * 8)] = def64leds[x];
		});
		~updateGrid64Leds.value;
	};
	~initCvSeq.value;
	~stopCvSeq = {
		~cvTask1.stop;
		~cvTask2.stop;
	};
});
)
//}
//a.push;
//);

a.pop
a.clear


