import { useEffect, useState } from "react";
import { Chart } from "./components/Chart";
import "./styles.css";

export default function App() {
  useEffect(() => {
    const fetchStoreMetrics = async () => {
      //const res = await fetch("https://api.coincap.io/v2/assets/?limit=5");
      
      const data = [{"name": "Orders in Queue","count": Math.floor((Math.random() * 10) + 1).toString()}];
      //await res.json();
      setStoreChartData({
        labels:  data.map((metric) => metric.name),
       
        datasets: [
          {
            label: "Count",
            data: data.map((metric) => metric.count),
            backgroundColor: [
              "#ffbb11",
              "#C0C0C0",
              "#50AF95",
              "#f3ba2f",
              "#2a71d0"
            ]
          }
        ]
      });
    };
    fetchStoreMetrics();
    setInterval( function() {fetchStoreMetrics();} , 2 * 1000); 
  }, []);

  const [chartData, setStoreChartData] = useState({});


  

  useEffect(() => {
    const fetchScaleMetrics = async () => {
      //const res = await fetch("https://api.coincap.io/v2/assets/?limit=5");
      const data = [{"name": "API Replicas","count": Math.floor((Math.random() * 100) + 1).toString()}, {"name": "Queue Replicas","count": Math.floor((Math.random() * 100) + 1).toString()}];
      //await res.json();
      setScaleChartData({
        labels:  data.map((metric) => metric.name),
        datasets: [
          {
            label: "Count",
            data: data.map((metric) => metric.count),
            backgroundColor: [
              "#ffbb11",
              "#C0C0C0",
              "#50AF95",
              "#f3ba2f",
              "#2a71d0"
            ]
          }
        ]
      });
    };
    
    fetchScaleMetrics()
    setInterval( function() {fetchScaleMetrics();} , 2 * 1000); 
  
  }, []);

  const [chartScaleData, setScaleChartData] = useState({});
  return (
    <div className="App">
        <div className="Chart">
          <h3>Store Operations</h3>          
          <Chart className="Chart" chartData={chartData} />
        </div>
        <div className="Chart">
          <h3>Scale Metrics</h3>
          <Chart className="Chart" chartData={chartScaleData} />
        </div>
    </div>
    
  );
}
