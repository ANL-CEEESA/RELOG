import React, { useEffect, useCallback, useRef } from 'react';
import dagre from 'dagre';
import {
  ReactFlow,ReactFlowProvider, useNodesState, useEdgesState, Background,
  Controls, Node, Edge, Connection, MarkerType, 
  getNodesBounds,
  getViewportForBounds,
  useReactFlow} from '@xyflow/react';
import { CircularPlant, CircularProduct, CircularCenter } from './CircularData';
import CustomNode, { CustomNodeData } from './NodesAndEdges';
import Section from '../Common/Section';
import Card from '../Common/Card';
import styles from './PipelineBlock.module.css';
import { toPng } from 'html-to-image';

interface PipelineBlockProps {
  onAddPlant: () => void;
  onAddProduct: () => void;
  onAddCenter: () => void;
  onMovePlant: (name: string, x: number, y: number) => void;
  onMoveProduct: (name: string, x: number, y: number) => void;
  onMoveCenter: (name: string, x: number, y: number) => void;
  onSetPlantInput: (plantName: string, productName: string) => void;
  onAddPlantOutput: (plantName: string, productName: string) => void;
  onAddCenterInput: (centerName: string, productName: string) => void;
  onAddCenterOutput: (centerName: string, productName: string) => void;
  onRemovePlant: (id: string) => void;
  onRemoveProduct: (id: string) => void;
  onRemoveCenter: (id: string) => void;
  onRenameProduct: (uid: string, newName: string) => void;
  onRenamePlant: (uid: string, newName: string) => void;
  onRenameCenter: (uid: string, newName: string) => void;
  products: Record<string, CircularProduct>;
  plants: Record<string, CircularPlant>;
  centers: Record<string, CircularCenter>;
}
 
function getLayouted(
  nodes: Node<CustomNodeData>[],
  edges: Edge[]
): { nodes: Node<CustomNodeData>[]; edges: Edge[] } {
  const W = 125, H = 45;
  const g = new dagre.graphlib.Graph();
  g.setDefaultEdgeLabel(() => ({}));
  g.setGraph({ rankdir: 'LR' });
  nodes.forEach(n => g.setNode(n.id, { width: W, height: H }));
  edges.forEach(e => g.setEdge(e.source, e.target));
  dagre.layout(g);
  return {
    nodes: nodes.map(n => {
      const d = g.node(n.id)!;
      return { ...n, position: { x: d.x - W/2, y: d.y - H/2 } };
    }),
    edges
  };
}
const PipelineBlock: React.FC<PipelineBlockProps> = props => {
  const mapRef = useRef<Record<string, 'plant'|'product'|'center'>>({});

  const flowWrapper = useRef<HTMLDivElement>(null);

  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
 
  const rebuild = useCallback(() => {
    const m: Record<string, 'plant'|'product'|'center'> = {};
    const newNodes: Node<CustomNodeData>[] = [];
    const newEdges: Edge[] = [];
    Object.entries(props.products).forEach(([key, p]) => {
      m[key] = 'product';
      newNodes.push({
        id: p.uid,
        type: 'default',
        data: { label: p.name, type: 'product' },
        position: { x: p.x, y: p.y },
        className: 'ProductNode'
      });
    });

    Object.entries(props.plants).forEach(([key, pl]) => {
      m[key] = 'plant';
      newNodes.push({
        id: pl.uid,
        type: 'default',
        data: { label: pl.name, type: 'plant' },
        position: { x: pl.x, y: pl.y },
        className: 'PlantNode'
      });

      pl.inputs.forEach(input => {
        newEdges.push({
          id: `${input}-${key}-in`,
          source: input,
          target: key,
          animated: true,
          style: { stroke: 'black' },
          markerEnd: { type: MarkerType.ArrowClosed }
        });
      });

      pl.outputs.forEach(output => {
        newEdges.push({
          id: `${key}-${output}-out`,
          source: key,
          target: output,
          animated: true,
          style: { stroke: 'black' },
          markerEnd: { type: MarkerType.ArrowClosed }
        });
      });
    });

    Object.entries(props.centers).forEach(([key, c]) => {
      m[key] = 'center';
      newNodes.push({
        id: c.uid,
        type: 'default',
        data: { label: c.name, type: 'center' },
        position: { x: c.x, y: c.y },
        className: 'CenterNode'
      });

      if (c.input) {
        newEdges.push({
          id: `${c.input}-${key}-in`,
          source: c.input,
          target: key,
          animated: true,
          style: { stroke: 'black' },
          markerEnd: { type: MarkerType.ArrowClosed }
        });

      }

      c.output.forEach(o => {
        newEdges.push({
          id: `${key}-${o}-out`,
          source: key,
          target: o,
          animated: true,
          style: { stroke: 'black' },
          markerEnd: { type: MarkerType.ArrowClosed }
        });
      });
    });
    mapRef.current = m;
    setNodes(newNodes);
    setEdges(newEdges);
  }, [

    props.products,
    props.plants,
    props.centers,
    setNodes,
    setEdges
  ]);
 
  useEffect(() => { rebuild(); }, [rebuild]);
    const onConnect = (c: Connection) => {
      const s = c.source!, t = c.target!;
      const st = mapRef.current[s], tt = mapRef.current[t];
      if (st==='product' && tt==='plant') props.onSetPlantInput(t, s);
      else if (st==='plant' && tt==='product') props.onAddPlantOutput(s, t);
      else if (st==='product' && tt==='center') props.onAddCenterInput(t, s);
      else if (st==='center' && tt==='product') props.onAddCenterOutput(s, t);
  };
 
  const onNodeDragStop = (_: any, n: Node<CustomNodeData>) => {
    const { id, position, data } = n;
    if (data.type==='plant') props.onMovePlant(id, position.x, position.y);
    if (data.type==='product') props.onMoveProduct(id, position.x, position.y);
    if (data.type==='center') props.onMoveCenter(id, position.x, position.y);
  };
 
  const handleNodesDelete = useCallback((deleted: Node<CustomNodeData>[]) => {
    deleted.forEach(n => {
      const t = mapRef.current[n.id];
      if (t==='plant') props.onRemovePlant(n.id);
      if (t==='product') props.onRemoveProduct(n.id);
      if (t==='center') props.onRemoveCenter(n.id);
    });

  }, [props]);
 
  const onNodeDoubleClick = (_: React.MouseEvent, n: Node<CustomNodeData>) => {
    const oldName = n.data.label;
    const newName = window.prompt('Enter new name', oldName);
    console.log('after rename', newName);
    const uniqueId = n.id;
    if (!newName || newName===oldName) return;
    if (n.data.type==='plant') props.onRenamePlant(uniqueId, newName);
    if (n.data.type==='product') props.onRenameProduct(uniqueId, newName);
    if (n.data.type==='center') props.onRenameCenter(uniqueId, newName);
  };
  function DownloadButton() {
    const onDownload = async () => {
      if (!flowWrapper.current) return;
      const node = flowWrapper.current;
      const { width, height } = node.getBoundingClientRect();
      const dataUrl = await toPng(node, {
        backgroundColor: '#fff',
        width: Math.round(width),
        height: Math.round(height)
      });
      const downloadLink = document.createElement('a');
      downloadLink.href = dataUrl;
      downloadLink.download = 'pipeline.png';
      downloadLink.click();
    };
    return <button style={{ margin: '0 8px' }} onClick={onDownload}>Export Pipeline</button>;
  };
 
  const onLayout = () => {
    const { nodes: ln, edges: le } = getLayouted(nodes, edges);
    ln.forEach(n => {
      const { id, position, data } = n;
      if (data.type==='plant') props.onMovePlant(id, position.x, position.y);
      else if (data.type==='product') props.onMoveProduct(id, position.x, position.y);
      else props.onMoveCenter(id, position.x, position.y);
    });
  };
 
  return (
<>
<Section title="Pipeline" />
<Card>
<ReactFlowProvider>
<div ref={flowWrapper} className={styles.PipelineBlock} style={{ width: '100%', height: 600 }}>
<ReactFlow

nodes={nodes}
edges={edges}
onNodesChange={onNodesChange}
onEdgesChange={onEdgesChange}
onConnect={onConnect}
onNodeDoubleClick={onNodeDoubleClick}
onNodeDragStop={onNodeDragStop}
onNodesDelete={handleNodesDelete}
deleteKeyCode="Delete"
maxZoom={1.25}
minZoom={0.5}
snapToGrid
preventScrolling
nodeTypes={{ default: CustomNode }}
>
<Background />
<Controls showInteractive={false} />
</ReactFlow>
</div>
 
<div style={{ textAlign: 'center', marginTop: '1rem' }}>
<button style={{ margin: '0 8px' }} onClick={props.onAddProduct}>Add product</button>
<button style={{ margin: '0 8px' }} onClick={props.onAddPlant}>Add plant</button>
<button style={{ margin: '0 8px' }} onClick={props.onAddCenter}>Add center</button>
<button style={{ margin: '0 8px' }} onClick={onLayout}>Auto Layout</button>
<DownloadButton />
<button style={{ margin: '0 8px' }} title="Drag & connect. Double-click to rename. Delete to remove.">?</button>

</div>
</ReactFlowProvider>
</Card>
</>

  );

};
 
export default PipelineBlock;

 