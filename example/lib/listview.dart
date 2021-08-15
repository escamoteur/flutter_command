import 'package:flutter/material.dart';

import 'main.dart';
import 'weather_manager.dart';

class WeatherListView extends StatelessWidget {
  WeatherListView();
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<WeatherEntry>>(
      valueListenable: weatherManager.updateWeatherCommand,
      builder: (BuildContext context, List<WeatherEntry> data, _) {
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (BuildContext context, int index) => ListTile(
            title: Text(data[index].cityName),
            subtitle: Text(data[index].description ?? ''),
            leading: data[index].iconURL != null
                ? Image.network(
                    data[index].iconURL!,
                    frameBuilder: (BuildContext context, Widget child,
                        int? frame, bool wasSynchronouslyLoaded) {
                      return child;
                    },
                    loadingBuilder: (BuildContext context, Widget child,
                        ImageChunkEvent? loadingProgress) {
                      if (loadingProgress == null) return child;
                      return CircularProgressIndicator();
                    },
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.error,
                      size: 40,
                    ),
                  )
                : SizedBox(),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${data[index].temperature}°C'),
                Text('${data[index].wind}km/h'),
              ],
            ),
          ),
        );
      },
    );
  }
}
