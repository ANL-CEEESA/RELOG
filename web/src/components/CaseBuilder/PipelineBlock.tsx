import  { CircularPlant, CircularProduct } from "./CircularData";
import { Node, Edge } from "@xyflow/react";
import styles from "./PipelineBlock.module.css";
import { ReactFlow, Background, Controls } from '@xyflow/react';
import Section from '../Common/Section';
import Card from '../Common/Card';
import  { useEffect } from "react";



interface PipelineBlockProps {
    onAddPlant: () => void;
    onAddProduct: () => void;
    onMovePlant: (name: string , x: number, y: number) => void;
    onMoveProduct: (name: string, x: number, y: number) => void;
    products: Record<string, CircularProduct>;
    plants: Record<string, CircularPlant>;
}
const onNodeDoubleClick = () => {};
const onNodeDragStop = () => {};
const onConnect = () => {};
const handleNodesDelete = () => {};
const handleEdgesDelete = () => {};
const onLayout = () => {};

const PipelineBlock: React.FC<PipelineBlockProps> = (props) => {
    const nodes: Node[] = [];
    const edges: Edge[] = [];

    let mapNameToType: Record<string,string> = {};
    let hasNullPositions: boolean = false;

    for (const [productName, product] of Object.entries(props.products) as [string, CircularProduct][]) {
        if(!product.x || !product.y) hasNullPositions = true;
        mapNameToType[productName] = "product";
        nodes.push({
            id: productName,
            type: "default",
            data: {label: productName, type: 'product'},
            position: { x:product.x, y:product.y}
        });
    }

    for (const [plantName, plant] of Object.entries(props.plants) as [string, CircularPlant][]) {
        if(!plant.x || !plant.y) hasNullPositions = true;
        mapNameToType[plantName] = "plant";
        nodes.push({
            id: plantName,
            type: "default",
            data: {label: plantName, type: 'plant'},
            position: { x:plant.x, y:plant.y}
        });

         if (plant) {
            edges.push({
                id: `${plantName}-${plantName}`,
                source: plantName,
                target: plantName,
                animated: true,
                style: { stroke: "black" },

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
          onEdgesDelete={handleEdgesDelete}
          deleteKeyCode={"Delete"}
          maxZoom={1.25}
          minZoom={0.5}
          snapToGrid={true}
          preventScrolling={false}
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
          onClick={onLayout}
        >
          Auto Layout
        </button>
        <button
          style={{ margin: "0 8px" }}
          title="Drag from one connector to another to create links between products and plants. Double click to rename an element. Click an element to select and move it. Press the [Delete] key to remove it."
        >
          ?
        </button>
      </div>
    </Card>
  </>
);
};

export default PipelineBlock;