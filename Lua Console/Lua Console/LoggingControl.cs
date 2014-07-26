using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Threading;

namespace Lua_Console
{
    public partial class LoggingControl : UserControl, ILogView
    {
        public LoggingControl()
        {
            InitializeComponent();
            richTextBox1.ContextMenuStrip = contextStrip;
        }

        private void appendColoredText(RichTextBox box, string s, Color color)
        {
            var len = box.TextLength;
            box.SelectionStart = len;
            box.SelectionColor = color;
            box.AppendText(s);
            box.DeselectAll();
        }

        private void logMessageImpl(Color color, string channel, string message)
        {
            var rtb = richTextBox1;
            appendColoredText(rtb, message, color);
            rtb.AppendText("\n");   
        }

        public void logMessage(Color color, string channel, string message)
        {
            richTextBox1.Invoke((Action)(() => logMessageImpl(color, channel, message)));
        }

        private void saveToolStripMenuItem_Click(object sender, EventArgs e)
        {

        }

        private void clearToolStripMenuItem_Click(object sender, EventArgs e)
        {
            richTextBox1.Text = "";
        }

    }
}
