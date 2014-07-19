using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Net.Sockets;
using System.Threading;
using System.Net;
using System.IO;

namespace Logger
{

    enum PageTag
    {
        Running = 0,
        Stopped = 1
    }

    public partial class LogMuch : Form
    {
        private TabPage selectedPage;
        private Color[] colorTable = new[] { Color.FromArgb(0xFF, 0, 0xaa, 0), Color.Orange, Color.Red };
      
        public LogMuch()
        {
            InitializeComponent();
            
            var thread = new Thread(() => ListenOnCllients(54321));
            thread.IsBackground = true;
            thread.Start();
        }

        private void ListenOnCllients(ushort port)
        {
            TcpListener listener = new TcpListener(new System.Net.IPEndPoint(IPExtensions.LocalIPAddress(), 0));
            listener.Start();

            LanBroadcaster.BroadcastPresence(((IPEndPoint)listener.LocalEndpoint).Address,
                                               ((IPEndPoint)listener.LocalEndpoint).Port);
            
            while (true)
            {
                var socket = listener.AcceptTcpClient();
                var thread = new Thread(() => ProcessLoggingMessages(socket));
                thread.IsBackground = true;
                thread.Start();
            }
        }

        private void ProcessLoggingMessages(TcpClient socket)
        {
            var reader = new BinaryReader(socket.GetStream());
            byte[] buffer = new byte[ushort.MaxValue];

            try
            {
                var tabNameLength = reader.ReadUInt16();
                reader.Read(buffer, 0, tabNameLength);
                //Ignore null terminator
                var tabName = Encoding.UTF8.GetString(buffer, 0, tabNameLength - 1);
                tabName = UniqueName(tabName);

                bool shouldProcess = true;
                while (shouldProcess)
                {
                    shouldProcess = ProcessMessage(reader, buffer, tabName);
                }

                LogMessage(tabName, "Logging Finished!", Color.Gold);
                StopLogging(tabName);
            }
            finally
            {
                socket.Close();
            }
        }

        private void StopLogging(string tabName)
        {
            tabControl1.Invoke(new Action(() =>
            {
                for (int i = 0; i < tabControl1.TabPages.Count; i++)
                {
                    var page = tabControl1.TabPages[i];
                    if (page.Name == tabName)
                    {
                        page.Tag = PageTag.Stopped;
                    }
                }

                tabControl1.Invalidate();
            }));
        }

        private bool canFind(string tabName)
        {
            for (int i = 0; i < tabControl1.TabCount; i++)
            {
                var tab = tabControl1.TabPages[i];
                if (tabName == tab.Text)
                {
                    return true;
                }
            }
            return false;
        }

        private string UniqueName(string tabName)
        {
            string name = tabName;
            int count = 0;
            while (true)
            {
                if (canFind(name))
                {
                    count++;
                    name = tabName + count;
                }
                else
                {
                    break;
                }
            }

            return name;
        }


        private bool ProcessMessage(BinaryReader reader, byte[] buffer, string tabName)
        {
            try
            {
                var verbosity = reader.ReadByte();
                if (verbosity > colorTable.Length)
                {
                    throw new Exception("Invalid verbosity! verb= " + verbosity);
                }
                Color color = colorTable[verbosity];
                
                int len = reader.ReadUInt16();
                var read = 0;
                while (len != 0)
                {
                    var r = reader.Read(buffer, read, len);
                    read += r;
                    len  -= r;
                }
                
                var message = Encoding.UTF8.GetString(buffer, 0, read);
                LogMessage(tabName, message, color);
            }
            catch (Exception e)
            {
                //Not much to do here. I think?
                LogMessage(tabName, "There was an error in the connection! " + e.Message, Color.Red);
                return false;
            }

            return true;
        }

        private void CreateTextTab(string tabName)
        {
            tabControl1.Invoke(new Action(() =>
            {
                var tabs = tabControl1;
                tabs.TabPages.Add(tabName);
                var page = tabs.TabPages[tabs.TabCount - 1];
                page.MouseClick += TextBoxMouseClick;
                page.Name = tabName;
                page.Tag = PageTag.Running;
            
                var tb = new RichTextBox();
                tb.MouseUp += TextBoxMouseClick;
                tb.BackColor = Color.Black;
                tb.Size = page.Size;
                tb.Margin = new Padding(0);
                tb.ReadOnly = true;
                tb.BorderStyle = BorderStyle.None;
                tb.Anchor = AnchorStyles.Top    | 
                            AnchorStyles.Bottom | 
                            AnchorStyles.Right  | 
                            AnchorStyles.Left;

                tb.Font = fontDialog1.Font;

                page.Controls.Add(tb);

             }));
        }

        private void TextBoxMouseClick(object sender, MouseEventArgs e)
        {
            if (e.Button == System.Windows.Forms.MouseButtons.Right)
            {
                textContextStrip.Show((Control)sender, e.Location);
            }
        }
        
        private void changeFontToolStripMenuItem_Click(object sender, EventArgs e)
        {
            if (fontDialog1.ShowDialog() == System.Windows.Forms.DialogResult.OK)
            {
                var font = fontDialog1.Font;

                for (int i = 0; i < tabControl1.TabCount; i++)
                {
                    var page = tabControl1.TabPages[i];
                    var rtb = page.Controls[0] as RichTextBox;
                    rtb.ForeColor = colorTable[0];
                    rtb.Font = font;
                }
            }
        }

        private void LogMessage(string tabName, string message, Color color)
        {
            tabControl1.Invoke(new Action(() =>
            {
                bool found = false;
                for (int i = 0; i < tabControl1.TabPages.Count; i++)
                {
                    var page = tabControl1.TabPages[i];
                    if (page.Name == tabName)
                    {
                        found = true;
                        var rtb = page.Controls[0] as RichTextBox;
                        appendColoredText(rtb, message, color);
                        rtb.AppendText("\n");
                    }
                }

                if (!found)
                {
                    CreateTextTab(tabName);
                    LogMessage(tabName, message, color);
                }
            }));
        }
        
        private void appendColoredText(RichTextBox box, string s, Color color)
        {
            var len = box.TextLength;
            box.SelectionStart = len;
            box.SelectionColor = color;
            box.AppendText(s);
            box.DeselectAll();
        }

        private void TabMouseClick(object sender, MouseEventArgs e)
        {
            if (e.Button == System.Windows.Forms.MouseButtons.Right)
            {
                var tabs = (TabControl)sender;
                for (int i = 0; i < tabs.TabCount; ++i)
                {
                    if (tabs.GetTabRect(i).Contains(e.Location))
                    {
                        selectedPage = tabs.TabPages[i];
                    }
                }

                contextMenuStrip1.Show((Control)sender, e.Location);
            }
        }

        private void saveToolStripMenuItem_Click(object sender, EventArgs e)
        {
            if (selectedPage != null)
            {
                saveFileDialog1.FileName = selectedPage.Text;

                if (DialogResult.OK == saveFileDialog1.ShowDialog())
                {
                    var rtb = selectedPage.Controls[0] as RichTextBox;

                    if (".rtf" == Path.GetExtension(saveFileDialog1.FileName))
                    {
                        rtb.SaveFile(saveFileDialog1.FileName);
                    }

                    if (".txt" == Path.GetExtension(saveFileDialog1.FileName))
                    {
                        using (StreamWriter writer = new StreamWriter(File.Create(saveFileDialog1.FileName)))
                        {
                            writer.Write(rtb.Text);
                        }
                    }
                }
            }
        }

        private void closeToolStripMenuItem_Click(object sender, EventArgs e)
        {
            //Close the tab page!
            tabControl1.TabPages.Remove(selectedPage);
            contextMenuStrip1.Hide();
        }
        
        private void clearToolStripMenuItem_Click(object sender, EventArgs e)
        {
            if (selectedPage != null)
            {
                var rtb = selectedPage.Controls[0] as RichTextBox;
                rtb.Text = "";
            }
        }

        private void closeAllToolStripMenuItem_Click(object sender, EventArgs e)
        {
            tabControl1.TabPages.Clear();
        }

        private void closeAllButThisToolStripMenuItem_Click(object sender, EventArgs e)
        {
            if (selectedPage != null)
            {
                for (int i = tabControl1.TabCount - 1; i >= 0; i--)
                {
                    if (tabControl1.TabPages[i] != selectedPage)
                    {
                        tabControl1.TabPages.RemoveAt(i);
                    }
                }
            }
        }


        private void ChangeTabColor(DrawItemEventArgs e)
        {
            Font TabFont;
            Brush BackBrush = new SolidBrush(Color.Black); //Set background color
            Brush ForeBrush = new SolidBrush(Color.LightGreen);//Set foreground color
            if (e.Index == this.tabControl1.SelectedIndex)
            {
               TabFont = new Font(e.Font, FontStyle.Italic | FontStyle.Bold);
            }
            else
            {
                TabFont = new Font(e.Font, FontStyle.Bold);
            }
           
            string TabName = this.tabControl1.TabPages[e.Index].Text;
            StringFormat sf = new StringFormat();
            sf.Alignment = StringAlignment.Center;
            e.Bounds.Inflate(new Size(2, 2));
            e.Graphics.FillRectangle(BackBrush, e.Bounds);
            e.Graphics.FillRectangle(BackBrush, new Rectangle(e.Bounds.Right, e.Bounds.Top, tabControl1.Size.Width - e.Bounds.Right, e.Bounds.Height));

            Rectangle r = e.Bounds;
            r = new Rectangle(r.X, r.Y + 3, r.Width, r.Height - 3);
            e.Graphics.DrawString(TabName, TabFont, ForeBrush, r, sf);
            //Dispose objects
            sf.Dispose();
            if (e.Index == this.tabControl1.SelectedIndex)
                {
                TabFont.Dispose();
                BackBrush.Dispose();
            }
            else
                {
                BackBrush.Dispose();
                ForeBrush.Dispose();
            }
        }

        private void tabControl1_DrawItem(object sender, DrawItemEventArgs e)
        {
            Brush backBrush = new SolidBrush(Color.Black); //Set background color
            Brush foreBrush;//Set foreground color

            Font selectedFont = new Font(e.Font, FontStyle.Italic | FontStyle.Bold);

            e.Graphics.FillRectangle(backBrush, new Rectangle(tabControl1.Bounds.Left, e.Bounds.Top, tabControl1.Bounds.Width, e.Bounds.Height));

            for (int i = 0; i < tabControl1.TabPages.Count; i++)
            {
                var page = tabControl1.TabPages[i];
                PageTag tag = (PageTag)page.Tag;
                foreBrush = new SolidBrush(colorTable[(int)tag]);

                var bounds = tabControl1.GetTabRect(i);
                DrawPageForeground(foreBrush, tabControl1.SelectedIndex == i ? selectedFont : e.Font, page, bounds, e.Graphics);
                foreBrush.Dispose();
            }

            selectedFont.Dispose();
            backBrush.Dispose();
        }

        private void DrawPageForeground(Brush brush, Font font, TabPage page, Rectangle bounds, Graphics graphics)
        {

            string TabName = page.Text;
            StringFormat sf = new StringFormat();
            sf.Alignment = StringAlignment.Center;
            graphics.DrawString(TabName, font, brush, bounds, sf);

            sf.Dispose();
        }
    }
}
