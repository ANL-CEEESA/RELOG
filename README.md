ReverseManufacturing.jl
=======================

**ReverseManufacturing.jl** is an optimization package for logistic decisions related to reverse manufacturing processes. For example, the package can be used to determine where to build recycling plants, what sizes should they have and which customers should be served by which plants. The package supports customized reverse manufacturing pipelines, with multiple types of plants, multiple types of product and multiple time periods.

Table of Contents
=================

  * [Installation](#installation)
  * [Typical Usage](#typical-usage)
     * [Describing an instance](#describing-an-instance)
     * [Optimizing](#optimizing)
  * [Current Limitations](#current-limitations)
  * [Authors](#authors)

Installation
------------
The package was developed and tested with Julia 1.3 and may not be compatible with newer versions. To install it, launch the Julia console, type `]` to switch to package manager mode and run:

```
pkg> add git@github.com:iSoron/ReverseManufacturing.git
```

To make sure that the package has been correctly installed:

```
pkg> test ReverseManufacturing
```

Typical Usage
-------------

### Describing an instance

The first step when using ReverseManufacturing.jl is describing the reverse manufacturing pipeline and the relevant data. Each input file is a JSON file with three sections: `parameters`, `products` and `plants`. Below, we describe each section in more detail. For a concrete example, see the file `instances/samples/s2.json`.

### Parameters

The **parameters** section describes details about the simulation itself.

| Key                     | Description
|:------------------------|---------------|
|`time periods`           | Number of time periods in the simulation.

#### Products

The **products** section describes all products and subproducts in the simulation. The field `instance["products"]` is a dictionary mapping the name of the product to a dictionary which describes its characteristics. Each product description contains the following keys:

| Key                     | Description
|:------------------------|---------------|
|`transportation cost`    | The cost (in dollars per km per tonnes) to transport this product. Must be a timeseries.
|`initial amounts`        | A dictionary mapping the name of each location to its description (see below). If this product is not initially available, this key may be omitted. Must be a timeseries.

Each product may have some amount available at the beginning of the simulation. In this case, the key `initial amounts` maps to a dictionary with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `latitude`              | The latitude of the location, in degrees.
| `longitude`             | The longitude of the location, in degrees.
| `amount`                | The amount (in tonnes) of the product initially available at the location. Must be a timeseries.

#### Processing Plants

The **plants** section describes the available types of reverse manufacturing plants, their potential locations and associated costs, as well as their inputs and outputs. The field `instance["plants"]` is a dictionary mapping the name of the plant to a dictionary with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `input`                 | The name of the product that this plant takes as input. Only one input is accepted per plant.
| `outputs`               | A dictionary specifying how many tonnes of each product is produced for each tonnes of input. For example, if the plant outputs 0.5 tonnes of P2 and 0.25 tonnes of P3 for each tonnes of P1 provided, then this entry should be `{"P2": 0.5, "P3": 0.25}`. If the plant does not output anything, this key may be omitted.
| `locations`             | A dictionary mapping the name of the location to a dictionary which describes the site characteristics (see below).

Each type of plant is associated with a set of potential locations where it can be built. Each location is represented by a dictionary with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `latitude`              | The latitude of the location, in degrees.
| `longitude`             | The longitude of the location, in degrees.
| `opening cost`          | The cost (in dollars) to open the plant.
| `fixed operating cost`  | The cost (in dollars) to keep the plant open, even if the plant doesn't process anything. Must be a timeseries.
| `variable operating cost` | The cost (in dollars per tonnes) that the plant incurs to process each tonnes of input. Must be a timeseries.
| `base capacity`         | The amount of input (in tonnes) the plant can process when zero dollars are spent on expansion. If unlimited, this key may be omitted.
| `max capacity`          | The amount (in tonnes) the plant can process when the maximum amount of dollars are spent on expansion. If unlimited, this key may be omitted. 
| `expansion cost`        | The cost (in dollars per tonnes) to increase the plant capacity beyond its base capacity. If zero, this key may be omitted. Must be a timeseries.
| `disposal`              | A dictionary describing what products can be disposed locally at the plant.

The keys in the disposal dictionary should be the names of the products. The values are dictionaries with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `cost`                  | The cost (in dollars per tonnes) to dispose of the product. Must be a timeseries.
| `limit`                 | The maximum amount (in tonnes) that can be disposed of. If an unlimited amount can be disposed, this key may be omitted. Must be a timeseries.

### Optimizing

After creating a JSON file describing the reverse manufacturing process and the input data, the following example illustrates how to use the package to find the optimal set of decisions:

```julia
using ReverseManufacturing
ReverseManufacturing.solve("/home/user/instance.json")
```

The optimal logistics plan will be printed to the screen.

Model Assumptions
-----------------
* Each plant can only be opened exactly once. After open, the plant remains open until the end of the simulation.
* Plants can be expanded at any time, even long after they are open.
* Variable and fixed operating costs do not change according to plant size.
* All material available at the beginning of a time period must be entirely processed by the end of that time period. It is not possible to store unprocessed materials from one time period to the next.

Authors
-------
* **Alinson S. Xavier,** Argonne National Laboratory <<axavier@anl.gov>>
* **Nwike Iloeje,** Argonne National Laboratory <<ciloeje@anl.gov>>