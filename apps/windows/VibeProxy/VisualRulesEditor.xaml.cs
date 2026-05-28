using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Shapes;
using Microsoft.UI.Xaml.Media;
using System;
using System.Collections.Generic;

namespace VibeProxy;

public sealed partial class VisualRulesEditor : Window
{
    private double _zoomLevel = 1.0;
    private readonly List<RuleNode> _nodes = new();

    public VisualRulesEditor()
    {
        this.InitializeComponent();
    }

    private void AddConditionNode_Click(object sender, RoutedEventArgs e)
    {
        AddNode("Condition", 100, 100);
    }

    private void AddActionNode_Click(object sender, RoutedEventArgs e)
    {
        AddNode("Action", 100, 200);
    }

    private void AddRouterNode_Click(object sender, RoutedEventArgs e)
    {
        AddNode("Router", 100, 300);
    }

    private void AddFilterNode_Click(object sender, RoutedEventArgs e)
    {
        AddNode("Filter", 100, 400);
    }

    private void AddNode(string type, double x, double y)
    {
        var node = new RuleNode
        {
            Type = type,
            X = x,
            Y = y
        };

        var border = new Border
        {
            Width = 120,
            Height = 80,
            Background = new SolidColorBrush(Microsoft.UI.Colors.LightBlue),
            BorderBrush = new SolidColorBrush(Microsoft.UI.Colors.DarkBlue),
            BorderThickness = new Thickness(2),
            CornerRadius = new CornerRadius(4)
        };

        var textBlock = new TextBlock
        {
            Text = type,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold
        };

        border.Child = textBlock;
        Canvas.SetLeft(border, x);
        Canvas.SetTop(border, y);
        RulesCanvas.Children.Add(border);

        _nodes.Add(node);
    }

    private void ZoomIn_Click(object sender, RoutedEventArgs e)
    {
        _zoomLevel = Math.Min(_zoomLevel + 0.1, 2.0);
        UpdateZoom();
    }

    private void ZoomOut_Click(object sender, RoutedEventArgs e)
    {
        _zoomLevel = Math.Max(_zoomLevel - 0.1, 0.5);
        UpdateZoom();
    }

    private void UpdateZoom()
    {
        ZoomLevel.Text = $"{_zoomLevel * 100:F0}%";
        // Apply zoom transform to canvas
        var transform = new ScaleTransform
        {
            ScaleX = _zoomLevel,
            ScaleY = _zoomLevel
        };
        RulesCanvas.RenderTransform = transform;
    }
}

internal class RuleNode
{
    public string Type { get; set; } = "";
    public double X { get; set; }
    public double Y { get; set; }
}
