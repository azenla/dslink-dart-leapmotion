import 'dart:math' as Math;
import 'package:leap_motion/vm.dart';
import "package:dslink/link.dart";

class Sample {
  Controller controller;

  Sample() {
    controller = new Controller(new VMWebSocket());
    controller.addEventListener(LeapEvent.LEAPMOTION_CONNECTED, onConnected);
    controller.addEventListener(LeapEvent.LEAPMOTION_FRAME, onFrame);
  }

  void onConnected(LeapEvent event) {
    //print("connected");
    controller.enableGesture(type: Gesture.TYPE_CIRCLE, enable: true);
    controller.enableGesture(type: Gesture.TYPE_SWIPE, enable: true);
    controller.enableGesture(type: Gesture.TYPE_SCREEN_TAP, enable: true);
    controller.enableGesture(type: Gesture.TYPE_KEY_TAP, enable: true);
  }

  void onFrame(LeapEvent event) {
    Frame frame = event.frame;

    //print("Frame id:" + frame.id.toString() + ", timestamp:" + frame.timestamp.toString() + ", hands:" + frame.hands.length.toString() + ", fingers:" + frame.fingers.length.toString() + ", tools:" + frame.tools.length.toString() + ", gestures:" + frame.gestures().length.toString());

    link["/hands/count"].value = Value.of(frame.hands.length);

    for (int i = 0; i < frame.hands.length; i++){
      // Get the first hand
      Hand hand = frame.hands[i];
      String handPath = "/hands/hand"+(i+1).toString();
      // Check if the hand has any fingers
      FingerList fingers = hand.fingerList;
      if (fingers.length > 0) {
        // Calculate the hand's average finger tip position
        Vector3 avgPos = Vector3.zero();
        for (int i = 0; i < fingers.length; i++) avgPos = avgPos + fingers[i].tipPosition;

        avgPos = avgPos / fingers.length.toDouble();
        //print("Hand has " + fingers.length.toString() + " fingers, average finger tip position:" + avgPos.toString());
      }

      // Get the hand's sphere radius and palm position
      
      link[handPath+"/sphereRadius"].value = Value.of(hand.sphereRadius);

      //print("Hand sphere radius:" + hand.sphereRadius.toString() + " mm, palm position:" + hand.palmPosition.toString());

      // Get the hand's normal vector and direction
      Vector3 normal = hand.palmNormal;
      Vector3 direction = hand.direction;

      // Calculate the hand's pitch, roll, and yaw angles
      //print("Hand pitch:" + LeapUtil.toDegrees(direction.pitch).toString() + " degrees, " + "roll:" + LeapUtil.toDegrees(normal.roll).toString() + " degrees, " + "yaw:" + LeapUtil.toDegrees(direction.yaw).toString() + " degrees\n");
    }

    List<Gesture> gestures = frame.gestures();
    for (int i = 0; i < gestures.length; i++) {
      Gesture gesture = gestures[i];

      switch (gesture.type) {
        case Gesture.TYPE_CIRCLE:
          CircleGesture circle = gesture as CircleGesture;

          // Calculate clock direction using the angle between circle normal and pointable
          String clockwiseness;
          if (circle.pointable.direction.angleTo(circle.normal) <= Math.PI / 4) {
            // Clockwise if angle is less than 90 degrees
            clockwiseness = "clockwise";
          } else {
            clockwiseness = "counterclockwise";
          }

          // Calculate angle swept since last frame
          double sweptAngle = 0.0;
          if (circle.state != Gesture.STATE_START) {
            Gesture previousGesture = controller.frame(history: 1).gesture(circle.id);
            if (previousGesture.isValid()) {
              sweptAngle = (circle.progress - (previousGesture as CircleGesture).progress) * 2 * Math.PI;
            }
          }
          
          link["/gestures/circle/state"].value = Value.of(getState(circle.state));
          link["/gestures/circle/direction"].value = Value.of(clockwiseness);
          link["/gestures/circle/sweptAngle"].value = Value.of(LeapUtil.toDegrees(sweptAngle));
          link["/gestures/circle/progress"].value = Value.of(circle.progress);
          link["/gestures/circle/radius"].value = Value.of(circle.radius);
          //print("Circle id:" + circle.id.toString() + ", " + circle.state.toString() + ", progress:" + circle.progress.toString() + ", radius:" + circle.radius.toString() + ", angle:" + LeapUtil.toDegrees(sweptAngle).toString() + ", " + clockwiseness);
          break;
        case Gesture.TYPE_SWIPE:
          SwipeGesture swipe = gesture as SwipeGesture;
          
          link["/gestures/swipe/state"].value = Value.of(getState(swipe.state));
          link["/gestures/swipe/direction"].value = Value.of(getDirection(swipe.direction));
          
          //print("Swipe id:" + swipe.id.toString() + ", " + swipe.state.toString() + ", position:" + swipe.position.toString() + ", direction:" + swipe.direction.toString() + ", speed:" + swipe.speed.toString());
          break;
        case Gesture.TYPE_SCREEN_TAP:
          ScreenTapGesture screenTap = gesture as ScreenTapGesture;
          //print("Screen Tap id:" + screenTap.id.toString() + ", " + screenTap.state.toString() + ", position:" + screenTap.position.toString() + ", direction:" + screenTap.direction.toString());
          break;
        case Gesture.TYPE_KEY_TAP:
          KeyTapGesture keyTap = gesture as KeyTapGesture;
          //print("Key Tap id:" + keyTap.id.toString() + ", " + keyTap.state.toString() + ", position:" + keyTap.position.toString() + ", direction:" + keyTap.direction.toString());
          break;
      }
    }
  }
}
String getState(int num) {
  var states = ["start", "update", "stop"];
  //print(states[num - 1]);
  return states[num - 1];
}

String getDirection(Vector3 vector) {
  var direction = "none";
  var isHorizontal = vector.x.abs() > vector.y.abs();
  //Classify as right-left or up-down
  if (isHorizontal) {
    if (vector.x > 0) {
      direction = "right";
    } else {
      direction = "left";
    }
  } else { //vertical
    if (vector.y > 0) {
      direction = "up";
    } else {
      direction = "down";
    }
  }

  return direction;
}


DSLink link;
main() {
  link = new DSLink("leapmotion2", host: "rnd.iot-dsa.org", sendInterval: 1000);


  //link.loadNodes();


  //print(rootNode.children);

  link.connect().then((_) {
    print("Connected.");
    Sample sample = new Sample();
  });

}
