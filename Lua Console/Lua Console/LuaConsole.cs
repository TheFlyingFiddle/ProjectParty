using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Net.Sockets;

namespace Lua_Console
{
    
    public partial class LuaConsole : UserControl, ILogView, ILuaConsole
    {
        private RichTextBox logBox, consoleBox;
        private IRemoteConnection _connection;

        public IRemoteConnection connection
        {
            get
            {
                return _connection;
            }
            set
            {
                this._connection = value;
                this._connection.onTermination += onConnectionTermination;
                this.textBox1.Enabled = true;
            }
        }

        public LuaConsole(IRemoteConnection connection)
        {
            InitializeComponent();

            logBox = initTextBox();
            logBox.Visible = false;

            consoleBox = initTextBox();
            consoleBox.Visible = true;

            this.Controls.Add(consoleBox);
            this.Controls.Add(logBox);

            comboBox1.SelectedIndex = 0;

            this.connection = connection;
        }

        private void onConnectionTermination()
        {
            textBox1.Invoke((Action)(() =>
            {
                    this._connection = null;
                    this.textBox1.Enabled = false;
            }));
        }

        private RichTextBox initTextBox()
        {
            var box = new RichTextBox();
            box.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            box.BackColor = SystemColors.Window;
            box.Font = new Font("Consolas", 9F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            box.Location = new Point(3, 3);
            box.Name = "richTextBox1";
            box.Size = new Size(570, 169);
            box.Text = "";
            return box;
        }

        private void appendColoredText(RichTextBox box, string s, Color color)
        {
            var len = box.TextLength;
            box.SelectionStart = len;
            box.SelectionColor = color;
            box.AppendText(s + "\n");
            box.DeselectAll();
        }

        private void textBox1_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Enter)
            {
                connection.sendConsoleInput(textBox1.Text + '\n');
                consoleBox.AppendText("> " + textBox1.Text + "\n");
                textBox1.Clear();

                e.Handled = e.SuppressKeyPress = true;
            }
        }

        public void logMessage(Color color, string channel, string message)
        {
            logBox.Invoke((Action)(() => appendColoredText(logBox, message, color)));
        }

        public void consoleResult(Color color, string result)
        {
            consoleBox.Invoke((Action)(() => appendColoredText(consoleBox, result, color)));
        }

        private void comboBox1_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (((string)comboBox1.SelectedItem) == "Show Log")
            {
                logBox.Visible = true;
                consoleBox.Visible = false;
                textBox1.Enabled = false;
            }
            else
            {
                logBox.Visible = false;
                consoleBox.Visible = true;
                textBox1.Enabled = true;
            }
        }

        private void saveToolStripMenuItem_Click(object sender, EventArgs e)
        {
            
        }

        private void clearToolStripMenuItem_Click(object sender, EventArgs e)
        {
            logBox.Text = "";
            consoleBox.Text = "";
        }

        private void closeToolStripMenuItem_Click(object sender, EventArgs e)
        {

        }
    }
}
