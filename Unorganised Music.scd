(
var sampleFolder, varInterpret;
~sampleListA = []; ~sampleListB = [];
~bufferVarList = [];

///////////// Default stuff
~hitChangeSpeedA = 0.2;
~hitChangeSpeedB = 0.2;
~outSpeed = 0.11;
~currentSampleA = 0;
~currentSampleB = 0;
~panA = -1.0;
~panB = 1.0;
~volumeA = 0.8;
~volumeB = 0.8;
~prevVolA = 0.8;
~prevVolB = 0.8;
~playingSamplesA = [0];
~playingSamplesB = [0];
~bufferNumberAccumulator = 0;
~addThisToA = "";
~addThisToB = "";
~goCount = 1;
~stopCount = 0;
~clapFourOn = false;
~kickFourOn = false;

///////////// Sample loader function
~sampleLoader = { |folder, deck|
  if(deck == "a", { ~sampleListA = []; }, { ~sampleListB = []; });

  folder.filesDo({ |f, i|
    if( f.extension != "asd" , {
      // Add filename to sampleList
      z = f.fileNameWithoutExtension.toLower.replace(" ", "_");
      if(deck == "a", { ~sampleListA = ~sampleListA.add(z); }, { ~sampleListB = ~sampleListB.add(z); });

      // Make buffer variable name
      x = "~s_" ++ z;

      // Create Buffer environment variable for sample
      (x + "= Buffer.readChannel(s," + f.fullPath.quote ++ ", channels: [0], bufnum:" + ~bufferNumberAccumulator ++");").interpret;

      // Put buffer and its number into array
      ~bufferVarList = ~bufferVarList.add([x, ~bufferNumberAccumulator]);

      // Increment Buffer Number
      ~bufferNumberAccumulator = ~bufferNumberAccumulator + 1;
    });
  });
};

///////////// Generic SynthDef for sample playback
SynthDef(\samplePlayer, {
  arg bufno=1, pan=0, vol=0.6;
  var sig;
  sig = PlayBuf.ar(1, bufno, doneAction: 2);
  sig = Compander.ar(sig, sig, 0.15, 6, 0.7);
  sig = Pan2.ar(Limiter.ar(sig, 0.9, 0.001), pan);
  Out.ar(0, sig * vol);
}).add;

///////////// Kick n' Clappp
~clappppp = Buffer.read(s, thisProcess.nowExecutingPath.dirname++"/sounds/clap.wav", bufnum: ~bufferNumberAccumulator);
~bufferNumberAccumulator = ~bufferNumberAccumulator + 1;
SynthDef(\four_clap, {
  var sig;
  sig = PlayBuf.ar(1, ~clappppp.bufnum, doneAction: 2);
  sig = Compander.ar(Limiter.ar(sig, 0.9, 0.001), sig, 0.15, 2, 0.7);
  Out.ar(0, sig!2 * 0.4);
}).add;
~kiiiick = Buffer.read(s, thisProcess.nowExecutingPath.dirname++"/sounds/kick.wav", bufnum: ~bufferNumberAccumulator);
~bufferNumberAccumulator = ~bufferNumberAccumulator + 1;
SynthDef(\four_kick, {
  var sig;
  sig = PlayBuf.ar(1, ~kiiiick.bufnum, doneAction: 2);
  sig = Compander.ar(sig, sig, 0.05, 10, 1);
  Out.ar(0, sig!2 * 0.5);
}).add;

///////////// TASKS
~hitChangeTaskA = Task({
  {
    ~playingSamplesA.do({
      arg n;
      ~currentSampleA = n;
      ~hitChangeSpeedA.wait;
    });
  }.loop;
});

~hitChangeTaskB = Task({
  {
    ~playingSamplesB.do({
      arg n;
      ~currentSampleB = n;
      ~hitChangeSpeedB.wait;
    });
  }.loop;
});

~outA = Task({
  {
    ~goCount.do({
      (
        instrument: "samplePlayer",
        bufno: ~currentSampleA,
        pan: ~panA,
        vol: ~volumeA
      ).play;
      ~outSpeed.wait;
    });
    ~stopCount.do({
      ~outSpeed.wait;
    });
  }.loop;
});

~outB = Task({
  {
    ~goCount.do({
      (
        instrument: "samplePlayer",
        bufno: ~currentSampleB,
        pan: ~panB,
        vol: ~volumeB
      ).play;
      ~outSpeed.wait;
    });
    ~stopCount.do({
      ~outSpeed.wait;
    });
  }.loop;
});

~clap_four = Task({
  {
    if(~clapFourOn == true, {
      ( instrument: 'four_clap' ).play;
      ~outSpeed.wait;
      ~outSpeed.wait;
      ~outSpeed.wait;
      ~outSpeed.wait;
      }, {
        ~outSpeed.wait;
    });
  }.loop;
});

~kick_four = Task({
  {
    if(~kickFourOn == true, {
      ( instrument: 'four_kick' ).play;
      ~outSpeed.wait;
      ~outSpeed.wait;
      ~outSpeed.wait;
      ~outSpeed.wait;
      }, {
        ~outSpeed.wait;
    });
  }.loop;
});

~mainTask = Task({
  ~hitChangeTaskA.start;
  ~hitChangeTaskB.start;
  ~outA.start;
  ~outB.start;
  ~clap_four.start;
  ~kick_four.start;
});

///////////// GUI
w = Window.new("unorganised music", Rect.newSides(0, 0, 1000, 700));
w.onClose_({~mainTask.stop; ~hitChangeTaskA.stop; ~hitChangeTaskB.stop; ~outA.stop; ~outB.stop; ~visuals.close; ~baggyshep.free; });
w.background = Color.rand;
w.front;

Button(w, Rect(20, 20, 80, 30)).states_([["start", Color.white, Color.red]]).action_({ ~mainTask.start; ~baggyshep.free; }).font_(Font("Monaco", 16));
Button(w, Rect(120, 20, 60, 30)).states_([["stop", Color.white, Color.red]]).action_({ ~mainTask.stop; ~hitChangeTaskA.stop; ~hitChangeTaskB.stop; ~outA.stop; ~outB.stop; ~clap_four.stop; }).font_(Font("Monaco", 16));
StaticText(w, Rect(200, 20, 600, 30)).string_("unorganised music").font_(Font("Monaco", 16, true)).stringColor_(Color.white);

Button(w, Rect(560, 20, 80, 30)).states_([["record", Color.white, Color.red]]).action_({ s.record; }).font_(Font("Monaco", 16));
Button(w, Rect(680, 20, 80, 30)).states_([["stop", Color.white, Color.red]]).action_({ s.stopRecording; }).font_(Font("Monaco", 16));

// Load initial samples
~sampleLoader.value(PathName(thisProcess.nowExecutingPath.dirname++"/sounds/"), "a");
~sampleLoader.value(PathName(thisProcess.nowExecutingPath.dirname++"/sounds/"), "b");

~leftDeck = ListView(w, Rect(20, 70, 200, 610)).items_(~sampleListA).background_(Color.green).font_(Font("Monaco", 16)).selectionMode_(\multi).selectionAction_({
  ~playingSamplesA = [];
  if(~leftDeck.selection == [], {
    ~playingSamplesA = [~s_000_silence_000];
    }, {
      ~leftDeck.selection.do({ |n|
        ~addThisToA = ~sampleListA[n.value];
        ~bufferVarList.do({ |k|
          if(k[0] == ("~s_" ++ ~addThisToA.value), {
            ~addThisToA = k[1];
          });
        });
        ~playingSamplesA = ~playingSamplesA.add(~addThisToA);
      });
  });
});

StaticText(w, Rect(240, 70, 140, 30)).string_("A change").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
d = NumberBox(w, Rect(240, 100, 140, 70)).value_(0.20).clipLo_(0.02).step_(0.01).scroll_step_(0.01).align_(\center).font_(Font("Monaco", 32, true)).action_({ arg num; ~hitChangeSpeedA = num.value; });

StaticText(w, Rect(400, 70, 140, 30)).string_("B change").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
d = NumberBox(w, Rect(400, 100, 140, 70)).value_(0.20).clipLo_(0.02).step_(0.01).scroll_step_(0.01).align_(\center).font_(Font("Monaco", 32, true)).action_({ arg num; ~hitChangeSpeedB = num.value; });

StaticText(w, Rect(330, 170, 120, 30)).string_("out").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
d = NumberBox(w, Rect(320, 200, 140, 70)).value_(0.11).clipLo_(0.01).step_(0.01).scroll_step_(0.01).align_(\center).font_(Font("Monaco", 32, true)).action_({ arg num; ~outSpeed = num.value; });

~panControlSpec = [-1.00, 1.00].asSpec;

~panANumberBox = NumberBox(w, Rect(240, 340, 140, 30)).align_(\center);
~panBNumberBox = NumberBox(w, Rect(400, 340, 140, 30)).align_(\center);

StaticText(w, Rect(240, 280, 140, 30)).string_("A pan").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
~panASlider = Slider(w, Rect(240, 310, 140, 30)).value_(0.0).action_({ arg p; ~panA = ~panControlSpec.map(p.value); ~panANumberBox.value_(~panA); });

StaticText(w, Rect(400, 280, 140, 30)).string_("B pan").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
~panBSlider = Slider(w, Rect(400, 310, 140, 30)).value_(1.0).action_({ arg p; ~panB = ~panControlSpec.map(p.value); ~panBNumberBox.value_(~panB); });

Button(w, Rect(240, 390, 140, 30)).states_([["MONO A", Color.white, Color.black]]).action_({ ~panA = 0; ~panANumberBox.value_(~panA); ~panB = 0; ~volumeA = 1.0; ~avol.value_(~volumeA); ~volumeB = 0.0; ~bvol.value_(~volumeB); ~panASlider.value_(0.5); }).font_(Font("Monaco", 16));

Button(w, Rect(400, 390, 140, 30)).states_([["MONO B", Color.white, Color.black]]).action_({ ~panB = 0; ~panBNumberBox.value_(~panB); ~panA = 0; ~volumeB = 1.0; ~bvol.value_(~volumeB); ~volumeA = 0.0; ~avol.value_(~volumeA); ~panBSlider.value_(0.5); ~panANumberBox.value_(~panA);}).font_(Font("Monaco", 16));

~avol = Slider(w, Rect(275, 440, 70, 160)).orientation_(\vertical).value_(0.8).action_({ arg v; ~volumeA = v.value; });

~bvol = Slider(w, Rect(435, 440, 70, 160)).orientation_(\vertical).value_(0.8).action_({ arg v; ~volumeB = v.value; });

Button(w, Rect(240, 610, 140, 30)).states_([["mute", Color.white, Color.red]]).action_({ if(~volumeA == 0, { ~volumeA = ~prevVolA; ~avol.value_(~volumeA); }, { ~prevVolA = ~volumeA; ~volumeA = 0; ~avol.value_(~volumeA); }); });

Button(w, Rect(400, 610, 140, 30)).states_([["mute", Color.white, Color.red]]).action_({ if(~volumeB == 0, { ~volumeB = ~prevVolB; ~bvol.value_(~volumeB); }, { ~prevVolB = ~volumeB; ~volumeB = 0; ~bvol.value_(~volumeB); }); });

DragSink(w, Rect(240, 650, 140, 30)).align_(\center).string_("drop folder").font_(Font("Monaco", 14, true)).receiveDragHandler_({ ~sampleLoader.value(PathName(View.currentDrag), "a"); ~leftDeck.items_(~sampleListA); });

DragSink(w, Rect(400, 650, 140, 30)).align_(\center).string_("drop folder").font_(Font("Monaco", 14, true)).receiveDragHandler_({ ~sampleLoader.value(PathName(View.currentDrag), "b"); ~rightDeck.items_(~sampleListB); });

~rightDeck = ListView(w, Rect(560, 70, 200, 610)).items_(~sampleListB).background_(Color.green).font_(Font("Monaco", 16)).selectionMode_(\multi).selectionAction_({
  ~playingSamplesB = [];
  if(~rightDeck.selection == [], {
    ~playingSamplesB = [9999];
    }, {
      ~rightDeck.selection.do({ |n|
        ~addThisToB = ~sampleListB[n.value];
        ~bufferVarList.do({ |k|
          if(k[0] == ("~s_" ++ ~addThisToB.value), {
            ~addThisToB = k[1];
          });
        });
        ~playingSamplesB = ~playingSamplesB.add(~addThisToB);
      });
  });
});

Button(w, Rect(780, 70, 200, 40)).states_([["STEREO", Color.white, Color.green]]).action_({ ~panA = -1.0; ~panBNumberBox.value_(-1.0); ~panB = 1.0; ~volumeB = 0.8; ~bvol.value_(~volumeB); ~volumeA = 0.8; ~avol.value_(~volumeA); ~panBSlider.value_(1.0); ~panASlider.value_(0.0); ~panANumberBox.value_(1.0);}).font_(Font("Monaco", 16));

Button(w, Rect(780, 130, 200, 40)).states_([["MONO", Color.white, Color.blue]]).action_({ ~panA = -0.0; ~panBNumberBox.value_(-0.0); ~panB = 0.0; ~volumeB = 0.8; ~bvol.value_(~volumeB); ~volumeA = 0.8; ~avol.value_(~volumeA); ~panBSlider.value_(0.5); ~panASlider.value_(0.5); ~panANumberBox.value_(0.0);}).font_(Font("Monaco", 16));

// LOOPS
StaticText(w, Rect(780, 200, 600, 30)).string_("clap").font_(Font("Monaco", 16, true)).stringColor_(Color.white);
Button(w, Rect(840, 200, 60, 30)).states_([["ON", Color.white, Color.rand]]).action_({ ~clapFourOn = true; }).font_(Font("Monaco", 16));
Button(w, Rect(920, 200, 60, 30)).states_([["OFF", Color.white, Color.rand]]).action_({ ~clapFourOn = false; }).font_(Font("Monaco", 16));

StaticText(w, Rect(780, 280, 600, 30)).string_("kick").font_(Font("Monaco", 16, true)).stringColor_(Color.white);
Button(w, Rect(840, 280, 60, 30)).states_([["ON", Color.white, Color.rand]]).action_({ ~kickFourOn = true; }).font_(Font("Monaco", 16));
Button(w, Rect(920, 280, 60, 30)).states_([["OFF", Color.white, Color.rand]]).action_({ ~kickFourOn = false; }).font_(Font("Monaco", 16));

// STUTTER
Button(w, Rect(780, 360, 200, 30)).states_([["PAUSE CHANGE", Color.white, Color.rand]]).font_(Font("Monaco", 16)).mouseDownAction_({ ~hitChangeTaskA.pause; ~hitChangeTaskB.pause; }).mouseUpAction_({ ~hitChangeTaskA.resume; ~hitChangeTaskB.resume; });


// STOP AND GO BUTTONS

~goShow = StaticText(w, Rect(790, 430, 100, 20)).string_("go: 1").font_(Font("Monaco", 16, true)).stringColor_(Color.white).align_(\center);
~stopShow = StaticText(w, Rect(870, 430, 100, 20)).string_("stop: 0").font_(Font("Monaco", 16, true)).stringColor_(Color.white).align_(\center);

Button(w, Rect(810, 460, 60, 20)).states_([["8", Color.white, Color.rand]]).action_({~goCount = 8; ~goShow.string_("go: 8")}).font_(Font("Monaco", 16));
Button(w, Rect(890, 460, 60, 20)).states_([["8", Color.white, Color.rand]]).action_({~stopCount = 8; ~stopShow.string_("stop: 8")}).font_(Font("Monaco", 16));

Button(w, Rect(810, 485, 60, 20)).states_([["7", Color.white, Color.rand]]).action_({~goCount = 7; ~goShow.string_("go: 7")}).font_(Font("Monaco", 16));
Button(w, Rect(890, 485, 60, 20)).states_([["7", Color.white, Color.rand]]).action_({~stopCount = 7; ~stopShow.string_("stop: 7")}).font_(Font("Monaco", 16));

Button(w, Rect(810, 510, 60, 20)).states_([["6", Color.white, Color.rand]]).action_({~goCount = 6; ~goShow.string_("go: 6")}).font_(Font("Monaco", 16));
Button(w, Rect(890, 510, 60, 20)).states_([["6", Color.white, Color.rand]]).action_({~stopCount = 6; ~stopShow.string_("stop: 6")}).font_(Font("Monaco", 16));

Button(w, Rect(810, 535, 60, 20)).states_([["5", Color.white, Color.rand]]).action_({~goCount = 5; ~goShow.string_("go: 5")}).font_(Font("Monaco", 16));
Button(w, Rect(890, 535, 60, 20)).states_([["5", Color.white, Color.rand]]).action_({~stopCount = 5; ~stopShow.string_("stop: 5")}).font_(Font("Monaco", 16));

Button(w, Rect(810, 560, 60, 20)).states_([["4", Color.white, Color.rand]]).action_({~goCount = 4; ~goShow.string_("go: 4")}).font_(Font("Monaco", 16));
Button(w, Rect(890, 560, 60, 20)).states_([["4", Color.white, Color.rand]]).action_({~stopCount = 4; ~stopShow.string_("stop: 4")}).font_(Font("Monaco", 16));

Button(w, Rect(810, 585, 60, 20)).states_([["3", Color.white, Color.rand]]).action_({~goCount = 3; ~goShow.string_("go: 3")}).font_(Font("Monaco", 16));
Button(w, Rect(890, 585, 60, 20)).states_([["3", Color.white, Color.rand]]).action_({~stopCount = 3; ~stopShow.string_("stop: 3")}).font_(Font("Monaco", 16));

Button(w, Rect(810, 610, 60, 20)).states_([["2", Color.white, Color.rand]]).action_({~goCount = 2; ~goShow.string_("go: 2")}).font_(Font("Monaco", 16));
Button(w, Rect(890, 610, 60, 20)).states_([["2", Color.white, Color.rand]]).action_({~stopCount = 2; ~stopShow.string_("stop: 2")}).font_(Font("Monaco", 16));

Button(w, Rect(810, 635, 60, 20)).states_([["1", Color.white, Color.rand]]).action_({~goCount = 1; ~goShow.string_("go: 1")}).font_(Font("Monaco", 16));
Button(w, Rect(890, 635, 60, 20)).states_([["1", Color.white, Color.rand]]).action_({~stopCount = 1; ~stopShow.string_("stop: 1")}).font_(Font("Monaco", 16));

Button(w, Rect(810, 660, 60, 20)).states_([["0", Color.white, Color.rand]]).action_({~goCount = 0; ~goShow.string_("go: 0")}).font_(Font("Monaco", 16));
Button(w, Rect(890, 660, 60, 20)).states_([["0", Color.white, Color.rand]]).action_({~stopCount = 0; ~stopShow.string_("stop: 0")}).font_(Font("Monaco", 16));
)