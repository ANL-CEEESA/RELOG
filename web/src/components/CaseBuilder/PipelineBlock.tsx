import  { CircularPlant, CircularProduct, CircularCenter } from "./CircularData";
import { Node, Edge } from "@xyflow/react";
import styles from "./PipelineBlock.module.css";
import { ReactFlow, Background, Controls, MarkerType } from '@xyflow/react';
import Section from '../Common/Section';
import Card from '../Common/Card';
import  { useEffect, useCallback } from "react";
import { Connection } from '@xyflow/react';
import  CustomNode, { CustomNodeData }from "./NodesAndEdges";



interface PipelineBlockProps {
    onAddPlant: () => void;
    onAddProduct: () => void;
    onAddCenter: () => void;
    onMovePlant: (name: string , x: number, y: number) => void;
    onMoveProduct: (name: string, x: number, y: number) => void;
    onMoveCenter: (name: string, x: number, y: number) => void;
    onSetPlantInput: (plantName:string, productName: string) => void;
    onAddPlantOutput: (plantName: string, productName: string) => void;
    onAddCenterInput: (plantName: string, productName: string) => void;
    onAddCenterOutput: (plantName: string, productName: string) => void;
    onRemovePlant: (id:string) => void;
    onRemoveProduct: (id: string) => void;
    onRemoveCenter: (id: string) => void;

    products: Record<string, CircularProduct>;
    plants: Record<string, CircularPlant>;
    centers: Record<string, CircularCenter>;
}
const onNodeDoubleClick = () => {};

const handleNodesDelete = () => {};
const handleEdgesDelete = () => {};
const onLayout = () => {};

const PipelineBlock: React.FC<PipelineBlockProps> = (props) => {
    const nodes: Node[] = [];
    const edges: Edge[] = [];

    let mapNameToType: Record<string,string> = {};
    let hasNullPositions: boolean = false;

  const onConnect = (params: Connection) => {
    const { source, target } = params;
    if (!source || ! target) return;

    const sourceType = mapNameToType[source];
    const targetType = mapNameToType[target];

    if (sourceType === "product" && targetType === "plant") {
      props.onSetPlantInput(target,source);
  } else if (sourceType === "plant" && targetType === "product") {
    props.onAddPlantOutput(source, target);
  }

  else if (sourceType === "product" && targetType === "center") {
    props.onAddCenterInput(target, source);
  }
  else if (sourceType === "center" && targetType === "product") {
    props.onAddCenterOutput(source, target);
  }

};

const onNodeDragStop =(_:any, node: Node) => {
  const { id, position, data} = node;
  if (data.type === "plant") {
    props.onMovePlant(id, position.x, position.y);
  } 
  if (data.type === "product") {
    props.onMoveProduct(id, position.x, position.y);
  }
  if (data.type === "center") {
    props.onMoveCenter(id, position.x, position.y);
  }

};
 const handleNodesDelete = useCallback((deleted: Node[]) => {
    deleted.forEach((n) => {
      const type = mapNameToType[n.id];
      if (type === "plant") {
        props.onRemovePlant(n.id);
      } else if (type === "product") {
        props.onRemoveProduct(n.id);
      } else if (type === "center") {
        props.onRemoveCenter!(n.id);
      }
    });
  }, [props, mapNameToType]);

    for (const [productName, product] of Object.entries(props.products) as [string, CircularProduct][]) {
        if(!product.x || !product.y) hasNullPositions = true;
        mapNameToType[productName] = "product";
        nodes.push({
            id: product.uid,
            type: "default",
            data: {label: product.name, type: 'product'},
            position: { x:product.x, y:product.y},
            className: 'ProductNode'
        });
    }
    for (const [plantName, plant] of Object.entries(props.plants) as [string, CircularPlant][]) {
        if(!plant.x || !plant.y) hasNullPositions = true;
        mapNameToType[plantName] = "plant";
        nodes.push({
            id: plant.uid,
            type: "default",
            data: {label: plant.name, type: 'plant'},
            position: { x:plant.x, y:plant.y},
            className: 'PlantNode'
        });

         if (plant) {
          for (const inputProduct of plant.inputs){
            edges.push({
                id: `${inputProduct}-${plantName}`,
                source: inputProduct,
                target: plantName,
                animated: true,
                style: { stroke: "black" },
                markerEnd: {
                  type: MarkerType.ArrowClosed,
                },

            });
          }
    for (const outputProduct of plant.outputs ?? []) {
    edges.push({
      id: `${plantName}-${outputProduct}`,
      source: plantName,
      target: outputProduct,
      animated: true,
      style: { stroke: 'black' },
      markerEnd: { type: MarkerType.ArrowClosed },
    });
  }  
         
    }

    }
  for (const [centerName, center] of Object.entries(props.centers)) {
    mapNameToType[centerName] = "center";
    nodes.push({
      id: center.uid,
      type: "default",
      data: { label: center.name, type: "center"},
      position: {x: center.x, y: center.y},
      className: 'CenterNode'
    });
    if (center.input) {
      edges.push({ 
        id: `${center.input}-${centerName}`,
        source: center.input,
        target:centerName,
        animated: true,
        style: { stroke: "black"},
        markerEnd: { type: MarkerType.ArrowClosed},
      });
    }
    for (const out of center.output) {
      edges.push({
        id: `${centerName}-${out}`,
        source: centerName,
        target:out,
        animated: true,
        style: { stroke: "black"},
        markerEnd: { type: MarkerType.ArrowClosed},
      });
    } 
  }
  
    

    useEffect(() => {
        if (hasNullPositions) onLayout();

    }, [hasNullPositions]);

   
return (
<>
<Section title="Pipeline" />
<Card>
<div className={styles.PipelineBlock}>
<ReactFlow

          nodes={nodes}
          edges={edges}
          onNodeDoubleClick={onNodeDoubleClick}
          onNodeDragStop={onNodeDragStop}
          onConnect={onConnect}
          onNodesDelete={handleNodesDelete}
          deleteKeyCode="Delete"
          maxZoom={1.25}
          minZoom={0.5}
          snapToGrid={true}
          preventScrolling={false}
          nodeTypes={{ default: CustomNode }}
>
<Background />
<Controls showInteractive={false} />
</ReactFlow>
</div>
<div style={{ textAlign: "center", marginTop: "1rem" }}>
<button
          style={{ margin: "0 8px" }}
          onClick={props.onAddProduct}
>
          Add product
</button>
<button
          style={{ margin: "0 8px" }}
          onClick={props.onAddPlant}
>
          Add plant
</button>
<button
          style={{ margin: "0 8px" }}
          onClick={props.onAddCenter}
>
          Add center
</button>
<button
          style={{ margin: "0 8px" }}
          onClick={onLayout}
>
          Auto Layout
</button>
<button
          style={{ margin: "0 8px" }}
          title="Drag from one connector to another to create links between products, plants, and centers. Double click to rename an element. Click an element to select and move it. Press the [Delete] key to remove it."
>
          ?
</button>
</div>
</Card>
</>
);
};
export default PipelineBlock;