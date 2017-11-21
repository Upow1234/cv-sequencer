//add master tune to this and cv keyboard

//get a delay where I can change the time from the ARC!!!!
//I think another grid will come in handy here...but for so few parameters????
//won't be so few with multiple sequences going
//should loop restart on moving loop offset?

//get all parameters to initalize correctly
//(
//a = Environment.make{
(
//client side variables

~noteData = Array.fill(16, 0);
~noteSelectionHeld = [0, 0, 0]; //first element is status, second is x location, third is y location
~noteIndex = Array.fill(16, 5);

~durData = Array.fill(16, 1);
~durationSelectionHeld = [0, 0, 5]; //first element is status, second is location, third is hard coded default index
~durationIndex = Array.fill(16, 5); //hard coded to the duration value where 1 is

~octaveSelectionHeld = [0, 0]; //first element is status, second is location
~octaveData = Array.fill(16, 0); //use 1 for synthdef
~octaveIndex = Array.fill(16, 3); //hard coded to octave 1

//variables for counting steps
~loopOffsetHeld = [0, 0]; //first element is status, second is location
~lengthHeld = [0, 0, 4]; //first element is status, second is location, third is value

~count = -1;
~length = 4;
~loopOffset = 0;

~sustainTime = 0.1;

~grid = MonoM.new("/monome", 0);
~arc = Arc.new("/monome", 0);
~grid64 = MonoM.new("/monome", 0);

~gridLeds = Array.fill(128, 0);
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
		var semi = [(0.1/12) *11.4, (0.1/12) * 9.3, (0.1/12) * 7.1, (0.1/12) * 3.9, (0.1/12) * 2.15, (0.1/12) * 0];
		//var semi = [200, 180, 160, 140, 120, 100];
		var durations = [0.125, 0.25, 0.375, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 3, 4, 6, 8, 12, 16]; // this should simply be better
		var octaves = [0.3, 0.2, 0.1, 0, -0.1, -0.2];
		//var octaves = [8, 4, 2, 1, 0.5, 0.25];
		var loopRowLeds = {
			//loop row leds
			for(0, 15, {arg x;
				~gridLeds[x + (7 * 16)] = 0;
			});
			for(~loopOffset, ~loopOffset + (~length - 1), {arg i;
				~gridLeds[(i % 16) + (7 * 16)] = 10;
			});
			~updateGridLeds.value;
		};
		postln(addr);
		if(message[2] < 6, { //top six rows
			switch(~octaveSelectionHeld[0], 0, {
				//holding note selection to select duration
				switch(message[3], 1, {
					~durationSelectionHeld = [1, message[1], ~durationIndex[message[1]]];
					~noteSelectionHeld = [1, message[1], message[2]];
					postln("new note is pre-selected");
					postln("duration selection is on");
					//display duration leds
					for(0, 15, {arg x;
						if(~durationIndex[message[1]] == x, {
							~gridLeds[x + (6 * 16)] = 10;
						}, {
							if(x.odd,{
								~gridLeds[x + (6 * 16)] = 3;
							}, {
								~gridLeds[x + (6 * 16)] = 0;
							});
						});
					});
					~updateGridLeds.value;
				}, 0, {
					//release duration selection held...stored value gets passed to acting value
					~durData[~durationSelectionHeld[1]] = durations[~durationSelectionHeld[2]];
					//postln("duration" + ~durationSelectionHeld[1] + "=" + durations[~durationSelectionHeld[2]]);
					//update note selection
					if(message[1] == ~noteSelectionHeld[1], {
						~noteData[~noteSelectionHeld[1]] = semi[~noteSelectionHeld[2]];
						~noteIndex[~noteSelectionHeld[1]] = ~noteSelectionHeld[2]; //this could cause a runtime bug I bet!
						postln("note" + message[1] + "=" + ~noteSelectionHeld[2]);
					});
					//update note selection led
					for(0, 6, {arg y;
						~gridLeds[message[1] + (y * 16)] = 0;
					});
					~gridLeds[message[1] + (message[2] * 16)] = 15;
					if(~durationSelectionHeld[1] == message[1], {
						~durationSelectionHeld[0] = 0;
						postln("duration selection is off");
						for(0, 15, {arg x;
							~gridLeds[x + (6 * 16)] = 0;
						});
						~updateGridLeds.value;
					});
				});
			}, 1, {
				//octave selection
				if(message[1] == ~octaveSelectionHeld[1], {
					~octaveData[~octaveSelectionHeld[1]] = octaves[message[2]];
					~octaveIndex[~octaveSelectionHeld[1]] = message[2];
					postln("octave" + ~octaveSelectionHeld[1] + "=" + ~octaveData[~octaveSelectionHeld[1]]);
					//update octave led
					for(0, 5, {arg y;
						if(~octaveIndex[~octaveSelectionHeld[1]] == y, {
							~gridLeds[~octaveSelectionHeld[1] + (y * 16)] = 7;
						}, {
							~gridLeds[~octaveSelectionHeld[1] + (y * 16)] = 0;
						});
					});
					~updateGridLeds.value;
				});
			});
		}, { //bottom two rows
			switch(message[2], 6, { //octave selection/duration row
				switch(message[3], 1, {
					switch(~durationSelectionHeld[0], 0, {
						postln("you're about to select your octave");
						~octaveSelectionHeld[0] = 1;
						~octaveSelectionHeld[1] = message[1]; //location of octave selection on x-axis
						for(0, 5, {arg y;
							if(~octaveIndex[message[1]] == y, {
								~gridLeds[~octaveSelectionHeld[1] + (y * 16)] = 7;
							}, {
								~gridLeds[~octaveSelectionHeld[1] + (y * 16)] = 0;
							});
						});
						~updateGridLeds.value;
					}, 1, {
						~durationSelectionHeld[2] = message[1];
						~durationIndex[~durationSelectionHeld[1]] = message[1];
						//update duration display led
						for(0, 15, {arg x;
							if(~durationIndex[~durationSelectionHeld[1]] == x, {
								~gridLeds[x + (6 * 16)] = 10;
							}, {
								if(x.odd,{
									~gridLeds[x + (6 * 16)] = 3;
								}, {
									~gridLeds[x + (6 * 16)] = 0;
								});
							});
						});
						~updateGridLeds.value;
					});
				}, 0, {
					switch(~durationSelectionHeld[0], 0, {
						//update note selection led after releasing octave selection
						for(0, 6, {arg y;
							if(~noteIndex[message[1]] == y, {
								~gridLeds[message[1] + (y * 16)] = 15;
							}, {
								~gridLeds[message[1] + (y * 16)] = 0;
							});
						});
						~updateGridLeds.value;
						postln("you're not selecting your octave anymore");
						~octaveSelectionHeld[0] = 0;
					}, 1, {
					});
				});
			}, 7, { //loop offset and length row
				switch(message[3], 1, {
					switch(~loopOffsetHeld[0], 0, {
						~loopOffsetHeld = [1, message[1]];
						postln("loop offset is held");
						//~loopRowLeds.value;
					}, 1, { //set length
						if(message[1] < ~loopOffsetHeld[1], { //for wrapping a length around the end of the grid
							~lengthHeld[2] = (16 - ~loopOffsetHeld[1]) + (message[1] + 1);
						}, {
							~lengthHeld = [1, message[1], (message[1] + 1) - ~loopOffsetHeld[1]]; //setting length without wrapping around the end of the grid
						});

					});
				}, 0, {
					switch(message[1], ~loopOffsetHeld[1],{
						~loopOffsetHeld[0] = 0; //watch out...i had troubles with arrays like this
						~loopOffset = ~loopOffsetHeld[1];
						~length = ~lengthHeld[2];
						postln("loop offset is not held");
					}, ~lengthHeld[1], {
						postln("loop length will equal =" + ~lengthHeld[2]);
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
		});
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
			var playPosition = (~count + ~loopOffset) % 16;
			if(x < 8, {
				//extra stuff for the playhead indicator
				if((x == (playPosition)) && (y < 7), {
					if(~gridLeds[index16] > 0, {
						tempGridLedsLeft[index8] = ~gridLeds[index16];
					}, {
						tempGridLedsLeft[index8] = 2;
					});
				}, {
					tempGridLedsLeft[index8] = ~gridLeds[index16];
				});
			}, {
				if((x == (playPosition)) && (y < 7), {
					if(~gridLeds[index16] > 0, {
						tempGridLedsRight[index8 - 8] = ~gridLeds[index16];
					}, {
						tempGridLedsRight[index8 - 8] = 2;
					});
				}, {
					tempGridLedsRight[index8 - 8] = ~gridLeds[index16];
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
		SynthDef("CVout", {arg freq, env, mul = 0.1, add = 0.1, gate = 0, attack = 0.001, release = 0.1, freqScale = 1;
			var envshape = Env([0, 0.2, 0], [attack, release], releaseNode: 1);
			var envgen = EnvGen.ar(envshape, gate);
			var pitch = SinOsc.ar(0.2, 0, mul, add);
			//var pitch2 = SinOsc.ar(0.2, 0, mul, freq);

			Out.ar(0, pitch);
			Out.ar(1, envgen);
			//Out.ar(2, pitch * freqScale);
			Out.ar(2, pitch * freqScale);
			/* for synthdef
			var pitch = PulseDPW.ar(add, 0.5, mul, 0);
			Out.ar([0, 1], pitch);
			*/
		}).add;
		s.sync;
		~cv1 = Synth("CVout", [\freq, 0, \mul, 0], ~cvSynths);
		//f = Synth("CVout", [\freq, 0, \mul, 0.1]); // for synthdef
		SynthDef("Delay", {arg delayTime = 1, decayTime = 1, delayLevel = 1;
			var input = SoundIn.ar(0, 1);
			var delay = CombC.ar(input, 4, Lag.kr(delayTime, 0.2), decayTime, delayLevel);
			Out.ar(7, input + delay);
		}).add;
		s.sync;
		~delay = Synth("Delay");
		s.sync;
		~pairs = [ //changes accessable by the arc
			[ArcParameter.new("Attack", 0.001, 10, 25, 2, 0.001, ~cvSynths, \attack, 0), ArcParameter.new("Release", 0.001, 10, 25, 2, 0.001, ~cvSynths, \release, 0)], [ArcParameter.new("Sustain Time", 0.001, 0.95, 100, 2, 0.1, ~susFunc, \nothing, -1), ArcParameter.new("Tempo", 10, 600, 5, 2, ~tempo, ~clockFunc, \nothing, -1)],

			[ArcParameter.new("Delay Time", 0.01, 3, 50, 2, 1, ~delay, \delayTime, 0), ArcParameter.new("Delay Feedback", 0.01, 15, 50, 2, 1, ~delay, \decayTime, 0)], [ArcParameter.new("Delay Level", 0, 1, 50, 2, 1, ~delay, \delayLevel, 0), ArcParameter.new("Cutoff Freq Scale", 0, 1, 100, 2, 1, ~cvSynths, \freqScale, 0)]
		];
	});

	~cvTask = Task({
		var time;

		loop{
			var position;
			~count = (~count + 1) % ~length;
			position = (~count + ~loopOffset) % 16;
			time = ~durData[position] / (~tempo/60); //adjusting for synthdef in seconds
			~cv1.set(\add, (~noteData[position]) + ~octaveData[position], \gate, 1);
			//update location leds
			~updateGridLeds.value;
			~clock.clear; //IF THERE ARE TIMING PROBLEMS GET RID OF THIS!!!
			~clock.sched(time * ~sustainTime,
				{
					~cv1.set(\gate, 0);
			});
			time.yield;
		};
	});
	~initCvSeq = {
		~updateArcLeds.value(0, ~pairs[0][0].arcLedValue);
		~updateArcLeds.value(1, ~pairs[0][1].arcLedValue);
		~updateArcLeds.value(2, ~pairs[1][0].arcLedValue);
		~updateArcLeds.value(3, ~pairs[1][1].arcLedValue);
		~cvTask.play(~clock);
		//initialize loop row leds
		for(0, 15, {arg x;
			~gridLeds[x + (5 * 16)] = 15;
			if((x >= ~loopOffset) && (x < (~loopOffset + ~length)), {
				~gridLeds[x + (7 * 16)] = 10;
			}, {
				~gridLeds[x + (7 * 16)] = 0;
			});
		});
		//initialze grid leds
		~updateGridLeds.value;
	};
	~initCvSeq.value;
});
)
//};
//)
a.push
a.pop
a.clear
//~initCvSeq.value
~cvTask.stop;

~grid.levall(0)
t.stop
f.free
s.queryAllNodes
~tempo = 10
