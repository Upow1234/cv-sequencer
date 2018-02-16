//add master tune to this and cv keyboard
//LET'S MAKE THE NUMBER OF SEQUENCES FUCKING DEEEEEEEEEEEP! later...

//individual envelope level controls?

//should loop restart on moving loop offset?

//can't figure out how to set grid 64 default leds to new default
//LOOK FOR AREAS THAT COULD BE CONSOLIDATED INTO CLASSES

//TASKS RUN ON THE CLIENT SIDE YOU DIPSHIT!!!

//get the arc parameter leds looking better!

//need to update internal synth initialization
s.options.memSize = 16384;

s.boot;
~sequ.value;

s.queryAllNodes;

(
~cvMode = 0;
~sequ = {
	//client side variables
	var numSeq = 2;
	var seqFoc = 0;

	var noteData;
	var noteSelectionHeld = Array.fill2D(numSeq, 1);
	var noteIndex = Array.fill2D(numSeq, 16, 5);

	var durData = Array.fill2D(numSeq, 16, 1);
	var durationSelectionHeld = Array.fill2D(numSeq, 1);
	var durationIndex = Array.fill2D(numSeq, 16, 5); //hard coded to the duration value where 1 is

	var octaveData;
	var octaveSelectionHeld = Array.fill2D(numSeq, 1);
	var octaveIndex = Array.fill2D(numSeq, 16, 3); //hard coded to octave 1

	//variables for counting steps
	var loopOffsetHeld = Array.fill2D(numSeq, 1);
	var lengthHeld = Array.fill2D(2, 1);

	var count = Array.fill(numSeq, -1);
	var length = Array.fill(numSeq, 4);
	var loopOffset = Array.fill(numSeq, 0);

	var grid = MonoM.new("/monome", 0);
	var arc = Arc.new("/monome", 0);
	var grid64 = MonoM.new("/monome", 0);

	var gridLeds = Array.fill2D(numSeq, 128, 0);
	var grid64Leds = Array.fill(64, 0);

	var arcSelectionLeft = [0, 0]; //left is holding status (one is held 0 is not) right is selection index
	var arcSelectionRight = [0, 1];
	var arcLedsSaved = [[4, 1], [7, 1]]; //this is misleading because it's grid leds not arc leds

	var tempo1 = 120;
	var tempo2 = tempo1;
	var tempoDeviation = 1;
	var clock1 = TempoClock(tempo1/60);
	var clock2 = TempoClock(tempo2/60);
	//functions for updating variables from ArcParameters
	var sustainTime = 0.58;
	var susFunc = {arg i;
		sustainTime = i;
	};
	var clockFunc = {arg i;
		tempo1 = i;
		clock1.tempo = i / 60;

		tempo2 = tempo1 * tempoDeviation;
		clock2.tempo = tempo2 / 60;
	};
	var tempoDeviationFunc = {arg i;
		tempoDeviation = i;
		tempo2 = tempo1 * i;
		clock2.tempo = tempo2 / 60;
	};

	var scale;

	var updateGridLeds = {
		var x, y, tempGridLedsLeft, tempGridLedsRight, gridWidth;
		gridWidth = 16;
		tempGridLedsLeft = Array.fill(64, 0);
		tempGridLedsRight = Array.fill(64, 0);

		for(0, 7, { arg y;
			for(0, 15, { arg x;
				var index16 = x + (y * gridWidth);
				var index8 = x + (y * 8);
				var playPosition = (count[seqFoc] + loopOffset[seqFoc]) % 16;
				if(x < 8, {
					//extra stuff for the playhead indicator
					if((x == (playPosition)) && (y < 7), {
						if(gridLeds[seqFoc][index16] > 0, {
							tempGridLedsLeft[index8] = gridLeds[seqFoc][index16];
						}, {
							tempGridLedsLeft[index8] = 2;
						});
					}, {
						tempGridLedsLeft[index8] = gridLeds[seqFoc][index16];
					});
				}, {
					if((x == (playPosition)) && (y < 7), {
						if(gridLeds[seqFoc][index16] > 0, {
							tempGridLedsRight[index8 - 8] = gridLeds[seqFoc][index16];
						}, {
							tempGridLedsRight[index8 - 8] = 2;
						});
					}, {
						tempGridLedsRight[index8 - 8] = gridLeds[seqFoc][index16];
					});
				});
			});
		});
		grid.levmap(0, 0, tempGridLedsLeft);
		grid.levmap(8, 0, tempGridLedsRight);
	};
	var updateGrid64Leds = {
		grid64.levmap(0, 0, grid64Leds);
	};
	var updateArcLeds = {arg encoderNumber, ledValue, ledLevel = 15;
		var encoderTemporaryArray = Array.fill(64, { arg index;
			if(index <= ledValue, { ledLevel }, { 0 });
		});
		arc.ringmap(encoderNumber, encoderTemporaryArray);

	};
	var synthsGroup = Group.basicNew(s, s.nextNodeID);
	var pairs;
	//parameter defaults
	var attack = 0.05;
	var release = 0.5;
	var sustain = sustainTime;
	var ampScale0 = 0.5;
	var ampScale1 = 0.5;

	//delay parameters
	var maxDelayTime = 30;
	var maxFeedbackTime = 240;
	var delayTime = 1;
	var decayTime = 3;
	var delayInputLevel = 0;
	var delayOutputLevel = 0;
	var lowShelfFreq = 133;
	var lowShelfAmp = 2.5;

	var lfoSpeed = 0.001;
	var lfoDepth = 0;
	//client side synth objects
	var synth0, synth1, lfo0, lfo1, lfo2;

	var gridWidth = 8;
	var selrow = [4, 5, 6, 7];
	var arcSelLeds = {arg row, col, side; //side = 0 for left encoders, side = 1 for right encoders
		var clear = {
			for(0, 7, {arg y;
				for(selrow[0], selrow[3], {arg x;
					grid64Leds[x + (y * gridWidth)] = 0;
				});
			});
		};
		var leds = {
			grid64Leds[arcLedsSaved[0][0] + (arcLedsSaved[0][1] * gridWidth)] = 15;
			grid64Leds[(arcLedsSaved[0][0] + 1) + (arcLedsSaved[0][1] * gridWidth)] = 15;
			grid64Leds[arcLedsSaved[1][0] + (arcLedsSaved[1][1] * gridWidth)] = 7;
			grid64Leds[(arcLedsSaved[1][0] - 1) + (arcLedsSaved[1][1] * gridWidth)] = 7;
			updateGrid64Leds.value;
		};
		switch(side, 0, {
			arcLedsSaved[0] = [selrow[row], col];
			clear.value();
			leds.value();
		}, 1, {
			arcLedsSaved[1] = [selrow[row], col];
			clear.value();
			leds.value();
		});
	};
	var leftenc = {arg messageTwo, messageThree, row;
		var pairBound = {arg offset; // check to make sure there is a parameter to go to
			var index = offset + (messageTwo * 2);
			if(index < pairs.size, {
				arcSelectionLeft[1] = index;
				//postln("arc selection left =" + arcSelectionLeft[1]);
				updateArcLeds.value(0, pairs[arcSelectionLeft[1]][0].arcLedValue);
				postln("");
				pairs[arcSelectionLeft[1]][0].displayName;
				updateArcLeds.value(1, pairs[arcSelectionLeft[1]][1].arcLedValue);
				pairs[arcSelectionLeft[1]][1].displayName;
				//postln("arc selection left is held");
				arcSelLeds.value(row, messageTwo, 0);
			});
		};
		switch(messageThree, 1, {
			if(arcSelectionLeft[0] == 0, {
				arcSelectionLeft[0] = 1;
				switch(row, 0, {
					pairBound.value(0);
				}, 2, {
					pairBound.value(1);
				});
			});
		}, 0, {
			if(arcSelectionLeft[0] == 1, {
				arcSelectionLeft[0] = 0;
				//postln("arc selection left is not held");
			});
		});
	};
	var rightenc = {arg messageTwo, messageThree, row;
		var pairBound = {arg offset; // check to make sure there is a parameter to go to
			var index = offset + (messageTwo * 2);
			if(index < pairs.size, {
				arcSelectionRight[1] = index;
				//postln("arc selection right =" + arcSelectionRight[1]);
				updateArcLeds.value(2, pairs[arcSelectionRight[1]][0].arcLedValue);
				postln("");
				pairs[arcSelectionRight[1]][0].displayName;
				updateArcLeds.value(3, pairs[arcSelectionRight[1]][1].arcLedValue);
				pairs[arcSelectionRight[1]][1].displayName;
				//postln("arc selection right is held");
				arcSelLeds.value(row, messageTwo, 1);
			});
		};
		switch(messageThree, 1, {
			if(arcSelectionRight[0] == 0, {
				arcSelectionRight[0] = 1;
				switch(row, 1, {
					pairBound.value(0);
				}, 3, {
					pairBound.value(1);
				});
			});
		}, 0, {
			if(arcSelectionRight[0] == 1, {
				arcSelectionRight[0] = 0;
				//postln("arc selection right is not held");
			});
		});
	};
	var cvTask1 = Task({ //seqFoc is subsituted for hard allocation here
		var time;

		loop{
			var seq = 0;
			var position;
			count[seq] = (count[seq] + 1) % length[seq];
			position = (count[seq] + loopOffset[seq]) % 16;
			time = durData[seq][position] / (tempo1/60); //adjusting for synthdef in seconds
			synth0.set(\add, (noteData[seq][position]) * octaveData[seq][position], \gate, 1);
			//update location leds
			updateGridLeds.value;
			//~clock.clear; //IF THERE ARE TIMING PROBLEMS GET RID OF THIS!!!
			clock1.sched(time * sustainTime, //WHAT ABOUT SUSTAIN TIME!!!!!!!!!!!??????????
				{
					synth0.set(\gate, 0);
			});
			time.yield;
		};
	});
	var cvTask2 = Task({ //seqFoc is subsituted for hard allocation here
		var time;

		loop{
			var seq = 1;
			var position;
			count[seq] = (count[seq] + 1) % length[seq];
			position = (count[seq] + loopOffset[seq]) % 16;
			time = durData[seq][position] / (tempo2/60); //adjusting for synthdef in seconds
			synth1.set(\add, (noteData[seq][position]) * octaveData[seq][position], \gate, 1); //seqFoc is subsituted for hard allocation here
			//update location leds
			updateGridLeds.value;
			//~clock.clear; //IF THERE ARE TIMING PROBLEMS GET RID OF THIS!!!
			clock2.sched(time * sustainTime,
				{
					synth1.set(\gate, 0);
			});
			time.yield;
		};
	});
	var initClient = {
		var octaves;

		if(~cvMode == 1, {
			noteData = Array.fill2D(numSeq, 16, 0);
			octaveData = Array.fill2D(numSeq, 16, 0);

			scale = [(0.1/12) * 11, (0.1/12) * 8.95, (0.1/12) * 7.1,
				(0.1/12) * 3.95, (0.1/12) * 2, (0.1/12) * 0];
			octaves = [0.3, 0.2, 0.1, 0, -0.1, -0.2];
		}, {
			var root = 60.midicps;
			noteData = Array.fill2D(numSeq, 16, root);
			octaveData = Array.fill2D(numSeq, 16, 1);

			scale = [70.midicps, 68.midicps, 67.midicps, 65.midicps, 63.midicps, 60.midicps];
			octaves = [8, 4, 2, 1, 0.5, 0.25];
			synth0 = Synth.basicNew("Internal", s, s.nextNodeID);
			synth1 = Synth.basicNew("Internal", s, s.nextNodeID);
		});
		//is this really necessary???
		for(0, (numSeq - 1), {arg i;
			noteSelectionHeld[i] = [0, 0, 0];
		}); //first element is status, second is x location, third is y location
		for(0, (numSeq - 1), {arg i;
			durationSelectionHeld[i] = [0, 0, 5];
		}); //first element is status, second is location, third is hard coded default index
		for(0, (numSeq - 1), {arg i;
			octaveSelectionHeld[i] = [0, 0];
		}); //first element is status, second is location
		for(0, (numSeq - 1), {arg i;
			loopOffsetHeld[i] = [0, 0];
		}); //first element is status, second is location
		for(0, (numSeq - 1), {arg i;
			lengthHeld[i] = [0, 0, 4]; //first element is status, second is location, third is value
		});

		OSCdef(\cvSeqGrid64, //64 grid
			{ arg message, time, addr, recvPort;
				//postln(message[1] + "" + message[2] + "" + message[3]);
				if(message[1] >= 4, { //arc selection columns

					switch(message[1], selrow[0],{
						leftenc.value(message[2], message[3], 0);
					}, selrow[1], {
						rightenc.value(message[2], message[3], 1);
					}, selrow[2], {
						leftenc.value(message[2], message[3], 2);
					}, selrow[3], {
						rightenc.value(message[2], message[3], 3);
					});
				}, {
					switch(message[1], 0, {
						seqFoc = 0;
						for(0, 7, {arg y;
							for(0, 1, {arg x;
								grid64Leds[x + (y * 8)] = 0;
							});
						});
						grid64Leds[0 + (0 * 8)] = 15;
						updateGrid64Leds.value;
					}, 1, {
						seqFoc = 1;
						for(0, 7, {arg y;
							for(0, 1, {arg x;
								grid64Leds[x + (y * 8)] = 0;
							});
						});
						grid64Leds[1 + (0 * 8)] = 15;
						updateGrid64Leds.value;
					});
					updateGrid64Leds.value;
				};
				);
		}, "/monome/grid/key", NetAddr("127.0.0.1", 15093));
		OSCdef(\cvSeqGrid128, //main 128 grid
			{ arg message, time, addr, recvPort;
				var semi = scale;
				var durations = [0.125, 0.25, 0.375, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 3, 4, 6, 8, 12, 16]; // this should simply be better
				var loopRowLeds = {
					//loop row leds
					for(0, 15, {arg x;
						gridLeds[seqFoc][x + (7 * 16)] = 0;
					});
					for(loopOffset[seqFoc], loopOffset[seqFoc] + (length[seqFoc] - 1), {arg i;
						gridLeds[seqFoc][(i % 16) + (7 * 16)] = 10;
					});
					updateGridLeds.value;
				};
				//postln(addr);
				if(message[2] < 6, { //top six rows
					switch(octaveSelectionHeld[seqFoc][0], 0, {
						//holding note selection to select duration
						switch(message[3], 1, {
							durationSelectionHeld [seqFoc]= [1, message[1], durationIndex[seqFoc][message[1]]];
							noteSelectionHeld [seqFoc]= [1, message[1], message[2]];
							postln("new note is pre-selected");
							postln("duration selection is on");
							//display duration leds
							for(0, 15, {arg x;
								if(durationIndex[seqFoc][message[1]] == x, {
									gridLeds[seqFoc][x + (6 * 16)] = 10;
								}, {
									if(x.odd,{
										gridLeds[seqFoc][x + (6 * 16)] = 3;
									}, {
										gridLeds[seqFoc][x + (6 * 16)] = 0;
									});
								});
							});
							updateGridLeds.value;
						}, 0, {
							//release duration selection held...stored value gets passed to acting value
							durData[seqFoc][durationSelectionHeld[seqFoc][1]] = durations[durationSelectionHeld[seqFoc][2]];
							//postln("duration" + durationSelectionHeld[seqFoc][1] + "=" + durations[durationSelectionHeld[seqFoc][2]]);
							//update note selection
							if(message[1] == noteSelectionHeld[seqFoc][1], {
								noteData[seqFoc][noteSelectionHeld[seqFoc][1]] = semi[noteSelectionHeld[seqFoc][2]];
								noteIndex[seqFoc][noteSelectionHeld[seqFoc][1]] = noteSelectionHeld[seqFoc][2]; //this could cause a runtime bug I bet!
								postln("note" + message[1] + "=" + noteSelectionHeld[seqFoc][2]);
							});
							//update note selection led
							for(0, 6, {arg y;
								gridLeds[seqFoc][message[1] + (y * 16)] = 0;
							});
							gridLeds[seqFoc][message[1] + (message[2] * 16)] = 15;
							if(durationSelectionHeld[seqFoc][1] == message[1], {
								durationSelectionHeld[seqFoc][0] = 0;
								postln("duration selection is off");
								for(0, 15, {arg x;
									gridLeds[seqFoc][x + (6 * 16)] = 0;
								});
								updateGridLeds.value;
							});
						});
					}, 1, {
						//octave selection
						if(message[1] == octaveSelectionHeld[seqFoc][1], {
							octaveData[seqFoc][octaveSelectionHeld[seqFoc][1]] = octaves[message[2]];
							octaveIndex[seqFoc][octaveSelectionHeld[seqFoc][1]] = message[2];
							postln("octave" + octaveSelectionHeld[seqFoc][1] + "=" + octaveData[seqFoc][octaveSelectionHeld[seqFoc][1]]);
							//update octave led
							for(0, 5, {arg y;
								if(octaveIndex[seqFoc][octaveSelectionHeld[seqFoc][1]] == y, {
									gridLeds[seqFoc][octaveSelectionHeld[seqFoc][1] + (y * 16)] = 7;
								}, {
									gridLeds[seqFoc][octaveSelectionHeld[seqFoc][1] + (y * 16)] = 0;
								});
							});
							updateGridLeds.value;
						});
					});
				}, { //bottom two rows
					switch(message[2], 6, { //octave selection/duration row
						switch(message[3], 1, {
							switch(durationSelectionHeld[seqFoc][0], 0, {
								postln("you're about to select your octave");
								octaveSelectionHeld[seqFoc][0] = 1;
								octaveSelectionHeld[seqFoc][1] = message[1]; //location of octave selection on x-axis
								for(0, 5, {arg y;
									if(octaveIndex[seqFoc][message[1]] == y, {
										gridLeds[seqFoc][octaveSelectionHeld[seqFoc][1] + (y * 16)] = 7;
									}, {
										gridLeds[seqFoc][octaveSelectionHeld[seqFoc][1] + (y * 16)] = 0;
									});
								});
								updateGridLeds.value;
							}, 1, {
								durationSelectionHeld[seqFoc][2] = message[1];
								durationIndex[seqFoc][durationSelectionHeld[seqFoc][1]] = message[1];
								//update duration display led
								for(0, 15, {arg x;
									if(durationIndex[seqFoc][durationSelectionHeld[seqFoc][1]] == x, {
										gridLeds[seqFoc][x + (6 * 16)] = 10;
									}, {
										if(x.odd,{
											gridLeds[seqFoc][x + (6 * 16)] = 3;
										}, {
											gridLeds[seqFoc][x + (6 * 16)] = 0;
										});
									});
								});
								updateGridLeds.value;
							});
						}, 0, {
							switch(durationSelectionHeld[seqFoc][0], 0, {
								//update note selection led after releasing octave selection
								for(0, 6, {arg y;
									if(noteIndex[seqFoc][message[1]] == y, {
										gridLeds[seqFoc][message[1] + (y * 16)] = 15;
									}, {
										gridLeds[seqFoc][message[1] + (y * 16)] = 0;
									});
								});
								updateGridLeds.value;
								postln("you're not selecting your octave anymore");
								octaveSelect		OSCdef(\cvSeqGrid128).enable;ionHeld[seqFoc][0] = 0;
							}, 1, {
							});
						});
					}, 7, { //loop offset and length[seqFoc] row
						switch(message[3], 1, {
							switch(loopOffsetHeld[seqFoc][0], 0, {
								loopOffsetHeld [seqFoc]= [1, message[1]];
								postln("loop offset is held");
								//~loopRowLeds.value;
							}, 1, { //set length[seqFoc]
								if(message[1] < loopOffsetHeld[seqFoc][1], { //for wrapping a length around the end of the grid
									lengthHeld[seqFoc][2] = (16 - loopOffsetHeld[seqFoc][1]) + (message[1] + 1);
								}, {
									lengthHeld [seqFoc]= [1, message[1], (message[1] + 1) - loopOffsetHeld[seqFoc][1]]; //setting length without wrapping around the end of the grid
								});

							});
						}, 0, {
							switch(message[1], loopOffsetHeld[seqFoc][1],{
								loopOffsetHeld[seqFoc][0] = 0; //watch out...i had troubles with arrays like this
								loopOffset[seqFoc] = loopOffsetHeld[seqFoc][1];
								length[seqFoc] = lengthHeld[seqFoc][2];
								postln("loop offset is not held");
							}, lengthHeld[seqFoc][1], {
								postln("loop length will equal =" + lengthHeld[seqFoc][2]);
							});
							loopRowLeds.value;
						});
					});
				});
		}, "/monome/grid/key", NetAddr("127.0.0.1", 10934));
		OSCdef(\cvSeqArc, //arc
			{ arg message, time, addr, recvPort;
				var arcFunctions = {arg name, messageOne, messageTwo, ledLevel = 15;
					name.change(messageTwo);
					name.sendChange;
					updateArcLeds.value(messageOne, name.arcLedValue, ledLevel);
				};
				switch(message[1], 0, {
					arcFunctions.value(pairs[arcSelectionLeft[1]][0], 0, message[2]);
				}, 1, {
					arcFunctions.value(pairs[arcSelectionLeft[1]][1], 1, message[2]);
				}, 2, {
					arcFunctions.value(pairs[arcSelectionRight[1]][0], 2, message[2]);
				}, 3, {
					arcFunctions.value(pairs[arcSelectionRight[1]][1], 3, message[2]);
				});
		}, "/monome/enc/delta");
		OSCdef(\cvSeqGrid128).enable;
		OSCdef(\cvSeqGrid64).enable;
		OSCdef(\cvSeqArc).enable;
	};
	var initServer = {
		grid.usePort(10934);
		arc.usePort(14394);
		grid64.usePort(15093);
		if(~cvMode == 1, {
			s.makeBundle(nil, {
				SynthDef("CVout", {arg mul = 0.1, add = 0.1, gate = 0, attack = 0.001, release = 0.1, freqScale = 1,
					pitchOut = 0, envOut = 1, freqOut = 2, ampScale = 1, pitchOffset;
					var envshape = Env([0, 1 * ampScale, 0], [attack, release], releaseNode: 1);
					var envgen = EnvGen.ar(envshape, gate);
					var pitch = SinOsc.ar(0.2, 0, mul, add + pitchOffset);

					Out.ar(pitchOut, pitch);
					Out.ar(envOut, envgen);
				}).add;
				SynthDef("ExtLFO", {arg lfoSpeed = 0.001, lfoDepth = 0, out;
					var lfo;
					lfo = SinOscFB.ar(lfoSpeed, 0, lfoDepth);
					Out.ar(out, lfo);
				}).add;
				s.sync;
				synthsGroup = Group.new;
				s.sync;
				synth0 = Synth("CVout", [\pitchOut, 0, \envOut, 1, \freq, 0, \mul, 0, \amp, 1,
					\attack, attack, \release, release, \ampScale, ampScale0], synthsGroup);
				synth1 = Synth("CVout", [\pitchOut, 0, \envOut, 1, \freq, 0, \mul, 0, \amp, 1,
					\attack, attack, \release, release, \ampScale, ampScale1], synthsGroup);
				lfo0 = Synth("CVout", [\out, 4, \lfoSpeed, lfoSpeed, \lfoDepth, lfoDepth], synthsGroup);
				lfo1 = Synth("CVout", [\out, 5, \lfoSpeed, lfoSpeed, \lfoDepth, lfoDepth], synthsGroup);
				lfo2 = Synth("CVout", [\out, 6, \lfoSpeed, lfoSpeed, \lfoDepth, lfoDepth], synthsGroup);
			});
			pairs = [ //changes accessable by the arc
				[ArcParameter.new("Attack", 0.001, 10, 25, 2, attack, synthsGroup, \attack, 0), ArcParameter.new("Release", 0.001, 10, 25, 2, release, synthsGroup, \release, 0)], [ArcParameter.new("Sustain Time", 0.001, 0.95, 100, 2, sustain, susFunc, \nothing, -1), ArcParameter.new("Tempo", 10, 600, 5, 2, tempo1, clockFunc, \nothing, -1)],
				/*
				[ArcParameter.new("Delay Time", 0.01, maxDelayTime, 10, 2, delayTime, ~delay, \delayTime, 0), ArcParameter.new("Delay Feedback", 0.01, maxFeedbackTime, 20, 2, decayTime, ~delay, \decayTime, 0)], [ArcParameter.new("Delay Input Level", 0, 1, 100, 2, delayInputLevel, ~delay, \delayInputLevel, 0), ArcParameter.new("Delay Output Level", 0, 1, 100, 2, delayOutputLevel, ~delay, \delayOutputLevel, 0)],
				*/
				[ArcParameter.new("Lfo One Speed", 0.0001, 50, 25, 2, lfoSpeed, lfo0, \lfoSpeed, 0), ArcParameter.new("Lfo One Depth", 0.0001, 1, 100, 2, lfoDepth, lfo0, \lfoDepth, 0)], [ArcParameter.new("Lfo Two Speed", 0.0001, 50, 25, 2, lfoSpeed, lfo1, \lfoSpeed, 0), ArcParameter.new("Lfo Two Depth", 0.0001, 1, 100, 2, lfoDepth, lfo1, \lfoDepth, 0)],

				[ArcParameter.new("Lfo Three Speed", 0.0001, 50, 25, 2, lfoSpeed, lfo2, \lfoSpeed, 0), ArcParameter.new("Lfo Three Depth", 0.0001, 1, 100, 2, lfoDepth, lfo2, \lfoDepth, 0)], [ArcParameter.new("Tempo Deviation", 1, 2, 100, 2, 1, tempoDeviationFunc, \nothing, -1), ArcParameter.new("Pitch Offset", -0.1, 0.1, 1000, 2, 0, synthsGroup, \pitchOffset, 0)],

				[ArcParameter.new("CV-1 Amp Scale", 0, 1, 100, 2, ampScale0, synth0, \ampScale, 0), ArcParameter.new("CV-2 Amp Scale", 0, 1, 100, 2, ampScale1, synth1, \ampScale, 0)]/*,
				[ArcParameter.new("Low Shelf Freq", 40, 500, 10, 2, lowShelfFreq, ~delay, \lowShelfFreq, 0), ArcParameter.new("Low Shelf Amplitude", 1, 4, 20, 2, lowShelfAmp, ~delay, \lowShelfAmp, 0)]
				*/
			];
		}, { //internal synth definitions
			s.makeBundle(nil, {
				SynthDef("Internal", {arg add = 0.1, gate = 0,
					attack = 0.001, release = 0.1, freqScale = 1,
					ampScale = 1, pitchOffset;

					var envshape = Env([0, 1 * ampScale, 0], [attack, release], releaseNode: 1);
					var envgen = EnvGen.ar(envshape, gate);
					var wave = SawDPW.ar(add, 0, 0.05);
					//var filter = DFM1.ar(wave, add * 8);

					Out.ar([0, 1], wave);
				}).add;
				s.sync;
				synthsGroup = Group.new;
				s.sync;
				synth0 = Synth("Internal",
					[\attack, attack, \release, release, \ampScale, ampScale0], synthsGroup);
				synth1 = Synth("Internal",
					[\attack, attack, \release, release, \ampScale, ampScale1], synthsGroup);
			});
			pairs = [ //changes accessable by the arc
				[ArcParameter.new("Attack", 0.001, 10, 25, 2, attack, synthsGroup, \attack, 0), ArcParameter.new("Release", 0.001, 10, 25, 2, release, synthsGroup, \release, 0)], [ArcParameter.new("Sustain Time", 0.001, 0.95, 100, 2, sustain, susFunc, \nothing, -1), ArcParameter.new("Tempo", 10, 600, 5, 2, tempo1, clockFunc, \nothing, -1)],

			];
		});

	};
	var initMonomeLeds = {
		updateArcLeds.value(0, pairs[arcSelectionLeft[1]][0].arcLedValue);
		updateArcLeds.value(1, pairs[arcSelectionLeft[1]][1].arcLedValue);
		updateArcLeds.value(2, pairs[arcSelectionRight[1]][0].arcLedValue);
		updateArcLeds.value(3, pairs[arcSelectionRight[1]][1].arcLedValue);
		//initialize loop row leds
		for(0, (numSeq - 1), {arg i;
			for(0, 15, {arg x;
				gridLeds[i][x + (5 * 16)] = 15;
				if((x >= loopOffset[seqFoc]) && (x < (loopOffset[seqFoc] + length[seqFoc])), {
					gridLeds[i][x + (7 * 16)] = 10;
				}, {
					gridLeds[i][x + (7 * 16)] = 0;
				});
			});
		});
		//initialze grid leds
		updateGridLeds.value;
		//initialize grid 64 leds
		for(0, 7, {arg x;
			var def64leds = [0, 0, 0, 0, 15, 15, 7, 7];
			grid64Leds[x + (0 * 8)] = def64leds[x]; //this is some hard coded bullshit
			grid64Leds[0 + (0 * 8)] = 15;
		});
		updateGrid64Leds.value;

	}; //end initMonomeLeds
	var initTasks = {
		cvTask1.play(clock1);
		cvTask2.play(clock2);
	};
	/*
	~stopCvSeq = {
	s.makeBundle(nil, {
	cvTask1.stop;
	cvTask2.stop;
	s.sync;
	synthsGroup.free;
	//~delay.free;
	lfo0.free;
	lfo1.free;
	lfo2.free;

	clock1.clear;
	clock2.clear;
	OSCdef(\cvSeqGrid128).clear;
	OSCdef(\cvSeqGrid64).clear;
	OSCdef(\cvSeqArc).clear;
	grid64.levall(0);
	});
	};
	*/
	initClient.value;
	initServer.value;
	initMonomeLeds.value;

	SystemClock.sched(1,
		{initTasks.value}
	);

}; //end main function
)





/*
(//pause
cvTask1.reset;
cvTask2.reset;
clock1.clear;
clock2.clear;
)

(//resume
s.makeBundle(nil, {
clock1 = TempoClock.new(tempo1 / 60);
clock2 = TempoClock.new(tempo2 / 60);
s.sync;
cvTask1.play(clock1);
cvTask2.play(clock2);
});
)

s.queryAllNodes
~stopCvSeq.value
a.pop
a.clear
currentEnvironment
*/

/*
SynthDef("Delay", {arg in = 0, out = 7, delayTime = 1, decayTime = 1,
delayInputLevel = 0, delayOutputLevel = 0, lowShelfFreq = 200, lowShelfAmp = 1;
var input = SoundIn.ar(in, 1);
var loShelf = BhobLoShelf.ar(input, lowShelfFreq, lowShelfAmp);
var filter = DFM1.ar(loShelf * delayInputLevel, 300, 0, type: 1);
var delay = CombC.ar(filter, maxDelayTime, Lag.kr(delayTime, 0.2), decayTime, delayOutputLevel);
var reverb = FreeVerb.ar(loShelf + delay, 0.5, 0.6, 0.2);
Out.ar(out, reverb);
}).add;
s.sync;

~delay = Synth("Delay", [\in, 0, \delayTime, delayTime, \decayTime, decayTime, \delayInputLevel, delayInputLevel, \delayOutputLevel, delayOutputLevel, \lowShelfFreq, lowShelfFreq, \lowShelfAmp, lowShelfAmp]);
s.sync;
*/
