import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<AudioPlayer>();
    return StreamBuilder(
      stream: player.sequenceStateStream,
      builder: (context, snapshot) {
        return snapshot.hasData && snapshot.data!.sequence.isNotEmpty
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // title
                  Expanded(
                    child: TextButton(
                      // onPressed: onPressed,
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => ModalPlayer(),
                        );
                      },
                      child: Text(
                        snapshot.data!.currentSource?.tag.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ),
                  // rewind 30 sec
                  IconButton(
                    icon: Icon(Icons.replay_30_rounded),
                    onPressed: () async {
                      final newPos = player.position - Duration(seconds: 30);
                      await player.seek(
                        newPos <= Duration.zero ? Duration.zero : newPos,
                      );
                    },
                  ),
                  // play or pause
                  StreamBuilder(
                    stream: player.playingStream,
                    builder: (context, snapshot) {
                      return snapshot.hasData
                          ? IconButton(
                              onPressed: () async {
                                snapshot.data!
                                    ? await player.pause()
                                    : await player.play();
                              },
                              icon: Icon(
                                snapshot.data!
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            )
                          : SizedBox(width: 0);
                    },
                  ),
                  // forward 30
                  IconButton(
                    icon: Icon(Icons.forward_30_rounded),
                    onPressed: () async {
                      final newPos = player.position + Duration(seconds: 30);
                      if (player.duration != null &&
                          newPos <= player.duration!) {
                        await player.seek(newPos);
                      }
                    },
                  ),
                ],
              )
            : SizedBox(height: 0);
      },
    );
  }
}

class ModalPlayer extends StatelessWidget {
  const ModalPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<AudioPlayer>();
    bool ignoreStream = false;
    double playerPos = 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // title
          // author
          // playlist
          StreamBuilder(
            stream: player.sequenceStateStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final index = snapshot.data!.currentIndex;
                final sequence = snapshot.data!.sequence;
                return Column(
                  children: [
                    Text(
                      index != null ? sequence[index].tag.album : '',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    // section
                    Text(
                      index != null ? sequence[index].tag.title : '',
                      style: TextStyle(
                        // fontSize: 16,
                        // fontWeight: FontWeight.w300,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              } else {
                return SizedBox(height: 0);
              }
            },
          ),
          SizedBox(height: 8),
          // first row: speed, position, volume
          StatefulBuilder(
            builder: (context, setState) {
              return StreamBuilder(
                stream: ignoreStream ? null : player.positionStream,
                builder: (context, asyncSnapshot) {
                  return Column(
                    children: [
                      // position slider
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 8.0,
                        ),
                        child: Slider(
                          value: ignoreStream
                              ? playerPos
                              : player.position.inSeconds.toDouble(),
                          min: 0.0,
                          max: player.duration?.inSeconds.toDouble() ?? 100.0,
                          padding: EdgeInsets.only(
                            top: 16,
                            left: 16,
                            right: 16,
                          ),
                          onChangeStart: (value) {
                            setState(() => ignoreStream = true);
                          },
                          onChanged: (value) {
                            setState(() => playerPos = value);
                          },
                          onChangeEnd: (value) async {
                            setState(() => ignoreStream = false);
                            await player.seek(Duration(seconds: value.toInt()));
                          },
                          label: secsToHhMmSs(playerPos.floor()),
                          divisions: 100,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(secsToHhMmSs(player.position.inSeconds)),
                          Text(secsToHhMmSs(player.duration?.inSeconds)),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          /*
          StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, snapshot) {
              return StatefulBuilder(
                builder: (context, setState) {
                  if (!ignoreStream && snapshot.hasData) {
                    playerPos =
                        snapshot.data?.inSeconds.toDouble() ?? playerPos;
                  }
                  return Column(
                    children: [
                      Slider(
                        value: playerPos,
                        max: player.duration?.inSeconds.toDouble() ?? 100.0,
                        padding: EdgeInsets.only(top: 16, left: 16, right: 16),
                        onChangeStart: (value) {
                          setState(() => ignoreStream = true);
                        },
                        onChanged: (value) {
                          setState(() => playerPos = value);
                        },
                        onChangeEnd: (value) async {
                          await player.seek(Duration(seconds: value.toInt()));
                          ignoreStream = false;
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(secsToHhMmSs(player.position.inSeconds)),
                          Text(secsToHhMmSs(player.duration?.inSeconds)),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          */
          // second row: begin, rewind, play, forward, end
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 16,
            children: [
              // to the beginning
              IconButton(
                icon: Icon(Icons.skip_previous_rounded, size: 24.0),
                onPressed: () async => await player.seek(Duration.zero),
              ),
              // rewind 30 sec
              IconButton(
                icon: Icon(Icons.replay_30_rounded, size: 24.0),
                onPressed: () async {
                  final newPos = player.position - Duration(seconds: 30);
                  await player.seek(
                    newPos <= Duration.zero ? Duration.zero : newPos,
                  );
                },
              ),
              // play or pause
              StreamBuilder<bool>(
                stream: player.playingStream,
                builder: (context, snapshot) {
                  return IconButton(
                    icon: Icon(
                      snapshot.data == true
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 42.0,
                    ),
                    onPressed: () async {
                      player.playing
                          ? await player.pause()
                          : await player.play();
                    },
                  );
                },
              ),
              // forward 30
              IconButton(
                icon: Icon(Icons.forward_30_rounded, size: 24.0),
                onPressed: () async {
                  final newPos = player.position + Duration(seconds: 30);
                  if (player.duration != null && newPos <= player.duration!) {
                    await player.seek(newPos);
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.skip_next_rounded, size: 24.0),
                onPressed: () async {
                  if (player.duration != null) {
                    await player.seek(player.duration!);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
