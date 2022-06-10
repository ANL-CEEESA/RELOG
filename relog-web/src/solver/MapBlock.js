import * as d3 from "d3";
import { group } from "d3-array";
import * as L from "leaflet";
import "leaflet/dist/leaflet.css";
import { useEffect, useState } from "react";
import { SERVER_URL } from "..";
import Card from "../common/Card";
import Section from "../common/Section";

function drawMap(csv_plants, csv_tr) {
  const mapLink = '<a href="http://openstreetmap.org">OpenStreetMap</a>';

  const base = L.tileLayer(
    "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
    {
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
      subdomains: "abcd",
      maxZoom: 10,
    }
  );

  const plant_types = [...new Set(csv_plants.map((d) => d["plant type"]))];
  plant_types.push("Multiple");
  const plant_color = d3
    .scaleOrdinal()
    .domain(plant_types)
    .range([
      "#558B2F",
      "#FF8F00",
      "#0277BD",
      "#AD1457",
      "#00838F",
      "#4527A0",
      "#C62828",
      "#424242",
    ]);

  const plant_locations = d3
    .nest()
    .key((d) => d["location name"])
    .rollup(function (v) {
      return {
        amount_processed: d3.sum(v, function (d) {
          return d["amount processed (tonne)"];
        }),
        latitude: d3.mean(v, function (d) {
          return d["latitude (deg)"];
        }),
        longitude: d3.mean(v, function (d) {
          return d["longitude (deg)"];
        }),
        plant_types: [...new Set(v.map((d) => d["plant type"]))],
      };
    })
    .entries(csv_plants);

  const plant_scale = d3
    .scaleSqrt()
    .range([2, 10])
    .domain([0, d3.max(plant_locations, (d) => d.value.amount_processed)]);

  const plants_array = [];
  plant_locations.forEach((d) => {
    if (d.value.plant_types.length > 1) {
      d.value.plant_type = "Multiple";
    } else {
      d.value.plant_type = d.value.plant_types[0];
    }
    const marker = L.circleMarker([d.value.latitude, d.value.longitude], {
      id: "circleMarker",
      className: "marker",
      color: "#222",
      weight: 1,
      fillColor: plant_color(d.value.plant_type),
      fillOpacity: 0.9,
      radius: plant_scale(d.value.amount_processed),
    });
    const num = d.value.amount_processed.toFixed(2);
    const num_parts = num.toString().split(".");
    num_parts[0] = num_parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    marker.bindTooltip(
      `<b>${d.key}</b>
          <br>
          Amount processed:
          ${num_parts.join(".")}
          <br>
          Plant types:
          ${d.value.plant_types}`
    );
    plants_array.push(marker);
  });

  const collection_centers = d3
    .nest()
    .key((d) => d["source location name"])
    .rollup(function (v) {
      return {
        source_lat: d3.mean(v, (d) => d["source latitude (deg)"]),
        source_long: d3.mean(v, (d) => d["source longitude (deg)"]),
        amount: d3.sum(v, (d) => d["amount (tonne)"]),
      };
    })
    .entries(csv_tr);

  //Color scale for the collection centers
  const colors = d3
    .scaleLog()
    .domain([
      d3.min(collection_centers, (d) => d.value.amount),
      d3.max(collection_centers, (d) => d.value.amount),
    ])
    .range(["#777", "#777"]);

  //Plot the collection centers
  const collection_array = [];
  collection_centers.forEach(function (d) {
    const marker = L.circleMarker([d.value.source_lat, d.value.source_long], {
      color: "#000",
      fillColor: colors(d.value.amount),
      fillOpacity: 1,
      radius: 1.25,
      weight: 0,
      className: "marker",
    });
    collection_array.push(marker);
  });

  const transportation_lines = group(
    csv_tr,
    (d) => d["source location name"],
    (d) => d["destination location name"]
  );

  //Plot the transportation lines
  const transport_array = [];
  transportation_lines.forEach(function (d1) {
    d1.forEach(function (d2) {
      const object = d2[0];
      const line = L.polyline(
        [
          [object["source latitude (deg)"], object["source longitude (deg)"]],
          [
            object["destination latitude (deg)"],
            object["destination longitude (deg)"],
          ],
        ],
        {
          color: "#666",
          stroke: true,
          weight: 0.5,
          opacity: Math.max(0.1, 0.5 / d1.size),
        }
      );
      transport_array.push(line);
    });
  });

  const plants = L.layerGroup(plants_array);
  const cities = L.layerGroup(collection_array);
  const transport = L.layerGroup(transport_array);

  const baseMaps = {
    "Open Street Map": base,
  };
  const overlayMaps = {
    Plants: plants,
    "Collection Centers": cities,
    "Transportation Lines": transport,
  };

  cities.on({
    add: function () {
      cities.eachLayer((layer) => layer.bringToBack());
    },
  });

  transport.on({
    add: function () {
      plants.eachLayer((layer) => layer.bringToFront());
    },
  });

  function setHeight() {
    let mapDiv = document.getElementById("map");
    mapDiv.style.height = `${+mapDiv.offsetWidth * 0.55}px`;
  }

  //$(window).resize(setHeight);

  setHeight();
  const map = L.map("map", {
    layers: [base, plants],
  }).setView([37.8, -96.9], 4);

  const svg6 = d3.select(map.getPanes().overlayPane).append("svg");
  svg6.append("g").attr("class", "leaflet-zoom-hide");

  L.control.layers(baseMaps, overlayMaps).addTo(map);
}

const MapBlock = (props) => {
  const [filesFound, setFilesFound] = useState(false);

  const fetchFiles = () => {
    const file_prefix = `${SERVER_URL}/jobs/${props.job}/case`;
    d3.csv(`${file_prefix}_plants.csv`).then((csv_plants) => {
      d3.csv(`${file_prefix}_tr.csv`).then((csv_tr) => {
        setFilesFound(true);
        drawMap(csv_plants, csv_tr, file_prefix);
      });
    });
  };

  // Fetch files periodically from the server
  useEffect(() => {
    fetchFiles();
    if (!filesFound) {
      const interval = setInterval(() => {
        fetchFiles();
      }, 1000);
      return () => clearInterval(interval);
    }
  }, [filesFound]);

  return (
    <>
      <Section title="Map" />
      <Card>
        <div id="map">
          <div className="nodata">No data available</div>
        </div>
      </Card>
    </>
  );
};

export default MapBlock;
