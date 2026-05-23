import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';

import 'replay_shared_state.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReplayMapTracksData>(
      valueListenable: replayMapTracksNotifier,
      builder: (context, mapTracks, _) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [
          Scaffold(
            body: FlutterMap(
              mapController: replayMapController,
              options: MapOptions(
                initialCenter: replayHomeCoords,
                initialZoom: 13.0,
                maxZoom: 18.0,
                cameraConstraint: const CameraConstraint.unconstrained(),
                keepAlive: true,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate & ~InteractiveFlag.flingAnimation,
                ),
                onLongPress: (tapPosition, point) {
                  if (mapTracks.tracks[0].first != const LatLng(0,0)) {
                    replayMapController.move(mapTracks.tracks[0].first, 13);
                  } else {
                    replayMapController.move(replayHomeCoords, 13);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'com.nmeatrax.app',
                  errorTileCallback: (tile, error, stackTrace) {},
                ),
                buildPolylinesLayer(mapTracks),
                const RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  showFlutterMapAttribution: false,
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      buildElevatedButtonRow(mapTracks),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PolylineLayer buildPolylinesLayer(ReplayMapTracksData mapTracks) {
    List<Polyline> polylines = [];
    int colorIndex = 0;
    for (List<LatLng> track in mapTracks.tracks) {
      final Polyline polyline = Polyline(
        points: track,
        color: mapTracks.colors[colorIndex],
        strokeWidth: 3.0,
      );
      polylines.add(polyline);
      colorIndex++;
    }

    return PolylineLayer(
      polylines: polylines,
    );
  }

  Widget buildElevatedButtonRow(ReplayMapTracksData mapTracks) {
    return ListView.builder(
      shrinkWrap: true,
      scrollDirection: Axis.horizontal,
      itemCount: mapTracks.numbers.length,
      itemBuilder: (lcontext, index) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(mapTracks.colors[index]),
            ),
            onPressed: () {
              replayMapController.move(mapTracks.tracks.elementAt(index).first, 13);
            },
            onLongPress: () {
              removeGpxTrackAt(index);
            },
            child: Icon(Icons.route_outlined, color: Theme.of(context).colorScheme.onPrimary),
          ),
        );
      },
    );
  }

}

class MapAppBar extends StatelessWidget {
  const MapAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(),
        ElevatedButton.icon(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
          ),
          icon: Icon(Icons.location_on, color: Theme.of(context).colorScheme.onPrimary,),
          label: Text("CSV", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
          onPressed: () => getGPXfromCSV(),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: ElevatedButton.icon(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
            ),
            icon: Icon(Icons.location_on, color: Theme.of(context).colorScheme.onPrimary,),
            label: Text("GPX", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
            onPressed: () => getGPX(File("null")),
          ),
        ),
      ],
    );
  }
}