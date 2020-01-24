ReverseManufacturing.jl
=======================

**ReverseManufacturing.jl** is an optimization package for logistic decisions related to reverse manufacturing processes. For example, the package can be used to determine where to build recycling plants, what sizes should they have and which customers should be served by which plants. The package supports customized reverse manufacturing pipelines, with multiple types of plants, multiple types of product and multiple time periods.

Table of Contents
=================

   * [ReverseManufacturing.jl](#reversemanufacturingjl)
      * [Installation](#installation)
      * [Typical Usage](#typical-usage)
         * [Describing an instance](#describing-an-instance)
            * [Products](#products)
            * [Processing Plants](#processing-plants)
         * [Optimizing](#optimizing)
      * [Current Limitations](#current-limitations)
      * [Authors](#authors)

Installation
------------
The package was developed and tested with Julia 1.3 and may not be compatible with newer versions. To install it, launch the Julia console, type `]` to switch to package manager mode and run:

```
pkg> add git@github.com:iSoron/ReverseManufacturing.git
```

To make sure that the package has been correctly installed

```
pkg> test ReverseManufacturing
```

Typical Usage
-------------

### Describing an instance

The first step when using ReverseManufacturing.jl is describing the reverse manufacturing pipeline and the relevant data. Each input file is a JSON file with two sections: `products` and `plants`. Below, we describe each section in more detail. For a concrete example, see the file `instances/samples/s2.json`.

#### Products

The **products** section describes all products and subproducts in the simulation. The field `instance["products"]` is a dictionary mapping the name of the product to a dictionary which describes its characteristics. Each product description contains the following keys:

* `transportation cost`, the cost (in dollars per km) to transport this product.
* `initial amounts,` a dictionary mapping the name of each location to its description (see below). If this product is not initially available, this key may be omitted.

Each product may have some amount available at the beginning of the simulation. In this case, the key `initial amounts` maps to a dictionary with the following keys:

* `latitude`, the latitude of the location, in degrees.
* `longitude`, the longitude of the location, in degrees.
* `amount`, the amount (in kg) of the product initially available at the location.

#### Processing Plants

The **plants** section describes the available types of reverse manufacturing plants, their potential locations and associated costs, as well as their inputs and outputs. The field `instance["plants"]` is a dictionary mapping the name of the plant to a dictionary with the following keys:

* `input`, the name of the product that this plant takes as input. Only one input is accepted per plant.
* `outputs`, a dictionary specifying how many kg of each product is produced for each kg of input. For example, if the plant outputs 0.5 kg of P2 and 0.25 kg of P3 for each kg of P1 provided, then this entry should be `{"P2": 0.5, "P3": 0.25}`. If the plant does not output anything, this key may be omitted.
* `locations`, a dictionary mapping the name of the location to a dictionary which describes the site characteristics (see below).

Each type of plant is associated with a set of potential locations where it can be built. Each location is represented by a dictionary with the following keys:

* `latitude`, the latitude of the location, in degrees.
* `longitude`, the longitude of the location, in degrees.
* `opening cost`, the cost (in dollars) to open the plant.
* `fixed operating cost`, the cost (in dollars) to keep the plant open, even if the plant doesn't process anything.
* `variable operating cost`, the cost (in dollars per kg) that the plant incurs to process each kg of input.

### Optimizing

After creating a JSON file describing the reverse manufacturing process and the input data, the following example illustrates how to use the package to find the optimal set of decisions:

```julia
using ReverseManufacturing

ReverseManufacturing.solve("/home/user/instance.json")
```

The optimal logistics plan will be printed to the screen.

Current Limitations
-------------------
* Each plant is only allowed exactly one product as input
* No support for multi-period simulations

Authors
-------
* **Alinson S. Xavier,** Argonne National Laboratory <<axavier@anl.gov>>
* **Nwike Iloeje,** Argonne National Laboratory <<ciloeje@anl.gov>>