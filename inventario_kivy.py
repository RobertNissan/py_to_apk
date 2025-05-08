from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.popup import Popup
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.textinput import TextInput
from kivy.uix.scrollview import ScrollView
from kivy.uix.gridlayout import GridLayout
from kivy.uix.checkbox import CheckBox
from kivy.core.window import Window
import sqlite3

# Fondo blanco, texto negro
t = (0,0,0,1)
Window.clearcolor = (1, 1, 1, 1)

class DBManager:
    def __init__(self, db_name='productos.db'):
        self.conn = sqlite3.connect(db_name)
        self.cursor = self.conn.cursor()
        self.create_table()

    def create_table(self):
        self.cursor.execute(
            '''CREATE TABLE IF NOT EXISTS productos
               (id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT,
                cantidad INTEGER,
                precio_fabrica REAL)'''
        )
        self.conn.commit()

    def add_producto(self, nombre, cantidad, precio_fabrica):
        self.cursor.execute(
            "INSERT INTO productos (nombre, cantidad, precio_fabrica) VALUES (?, ?, ?)",
            (nombre, cantidad, precio_fabrica)
        )
        self.conn.commit()

    def get_productos(self):
        self.cursor.execute("SELECT * FROM productos ORDER BY nombre ASC")
        return self.cursor.fetchall()

    def buscar_productos(self, texto):
        self.cursor.execute(
            "SELECT * FROM productos WHERE nombre LIKE ? ORDER BY nombre ASC", (f"%{texto}%",)
        )
        return self.cursor.fetchall()

    def delete_producto(self, producto_id):
        self.cursor.execute("DELETE FROM productos WHERE id=?", (producto_id,))
        self.conn.commit()

    def editar_producto(self, producto_id, nombre, cantidad, precio_fabrica):
        self.cursor.execute(
            "UPDATE productos SET nombre=?, cantidad=?, precio_fabrica=? WHERE id=?",
            (nombre, cantidad, precio_fabrica, producto_id)
        )
        self.conn.commit()

class ProductoForm(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(orientation='vertical', **kwargs)
        self.db = DBManager()
        self.selected_producto_id = None
        self.checkboxes = {}

        # Búsqueda
        self.buscar_input = TextInput(
            hint_text='Buscar producto', size_hint_y=None, height=40,
            foreground_color=t, background_color=(1,1,1,1)
        )
        self.buscar_input.bind(text=self.buscar_productos)
        self.add_widget(self.buscar_input)

        # Formulario
        form = BoxLayout(size_hint_y=None, height=50)
        self.nombre_input = TextInput(hint_text='Nombre', foreground_color=t, background_color=(1,1,1,1))
        self.cantidad_input = TextInput(
            hint_text='Cantidad', input_filter='int',
            foreground_color=t, background_color=(1,1,1,1)
        )
        self.precio_input = TextInput(
            hint_text='Precio', input_filter='float',
            foreground_color=t, background_color=(1,1,1,1)
        )
        btn_add = Button(text='Agregar')
        btn_add.bind(on_release=lambda x: self.add_producto())
        form.add_widget(self.nombre_input)
        form.add_widget(self.cantidad_input)
        form.add_widget(self.precio_input)
        form.add_widget(btn_add)
        self.add_widget(form)

        # Acciones
        actions = BoxLayout(size_hint_y=None, height=40)
        btn_del = Button(text='Eliminar seleccionado')
        btn_del.bind(on_release=self.confirmar_eliminar)
        btn_edit = Button(text='Editar seleccionado')
        btn_edit.bind(on_release=self.editar_seleccionado)
        actions.add_widget(btn_del)
        actions.add_widget(btn_edit)
        self.add_widget(actions)

        # Lista
        scroll = ScrollView()
        self.productos_layout = GridLayout(cols=1, spacing=5, size_hint_y=None)
        self.productos_layout.bind(minimum_height=self.productos_layout.setter('height'))
        scroll.add_widget(self.productos_layout)
        self.add_widget(scroll)

        self.load_productos()

    def add_producto(self):
        try:
            n = self.nombre_input.text.strip()
            c = int(self.cantidad_input.text.strip())
            p = float(self.precio_input.text.strip())
            if not n: raise ValueError('Nombre vacío')
            self.db.add_producto(n, c, p)
            self.nombre_input.text = ''
            self.cantidad_input.text = ''
            self.precio_input.text = ''
            self.load_productos()
        except Exception as e:
            self.show_popup('Error', str(e))

    def load_productos(self, productos=None):
        self.productos_layout.clear_widgets()
        self.selected_producto_id = None
        self.checkboxes.clear()
        if productos is None:
            productos = self.db.get_productos()
        for prod in productos:
            box = BoxLayout(size_hint_y=None, height=40)
            # Nombre 40%
            lbl_n = Label(text=prod[1], color=t, size_hint_x=0.4, halign='left')
            lbl_n.bind(size=lambda w, v: setattr(w, 'text_size', (w.width, None)))
            # Cantidad 20% derecha
            lbl_c = Label(text=str(prod[2]), color=t, size_hint_x=0.2, halign='right')
            lbl_c.bind(size=lambda w, v: setattr(w, 'text_size', (w.width, None)))
            # Precio 20% derecha
            lbl_p = Label(text=f"{prod[3]:.2f}", color=t, size_hint_x=0.2, halign='right')
            lbl_p.bind(size=lambda w, v: setattr(w, 'text_size', (w.width, None)))
            # Checkbox 20%
            cb = CheckBox(size_hint_x=0.2)
            cb.bind(active=self.on_checkbox_active)
            self.checkboxes[cb] = prod[0]

            box.add_widget(lbl_n)
            box.add_widget(lbl_c)
            box.add_widget(lbl_p)
            box.add_widget(cb)
            self.productos_layout.add_widget(box)

    def on_checkbox_active(self, checkbox, value):
        if value:
            for cb in self.checkboxes:
                if cb != checkbox:
                    cb.active = False
            self.selected_producto_id = self.checkboxes[checkbox]
        else:
            if self.selected_producto_id == self.checkboxes.get(checkbox):
                self.selected_producto_id = None

    def confirmar_eliminar(self, inst):
        if not self.selected_producto_id:
            return self.show_popup('Atención', 'No hay producto seleccionado.')
        content = BoxLayout(orientation='vertical', spacing=5)
        content.add_widget(Label(text='¿Eliminar producto?', color=t))
        btns = BoxLayout(size_hint_y=None, height=40)
        b1 = Button(text='Sí'); b2 = Button(text='No')
        btns.add_widget(b1); btns.add_widget(b2)
        content.add_widget(btns)
        pop = Popup(title='Confirmar', content=content, size_hint=(0.6,0.4))
        b1.bind(on_release=lambda x: (self.eliminar_seleccionado(), pop.dismiss()))
        b2.bind(on_release=pop.dismiss)
        pop.open()

    def eliminar_seleccionado(self):
        self.db.delete_producto(self.selected_producto_id)
        self.load_productos()

    def editar_seleccionado(self, inst):
        if not self.selected_producto_id:
            return self.show_popup('Atención', 'No hay producto seleccionado.')
        prod = next(p for p in self.db.get_productos() if p[0]==self.selected_producto_id)
        self.show_editar_popup(prod)

    def buscar_productos(self, inst, txt):
        lst = self.db.buscar_productos(txt) if txt.strip() else self.db.get_productos()
        self.load_productos(lst)

    def show_editar_popup(self, prod):
        content = BoxLayout(orientation='vertical', spacing=5, padding=5)
        in_n = TextInput(text=prod[1], foreground_color=t, background_color=(1,1,1,1))
        in_c = TextInput(text=str(prod[2]), input_filter='int', foreground_color=t, background_color=(1,1,1,1))
        in_p = TextInput(text=str(prod[3]), input_filter='float', foreground_color=t, background_color=(1,1,1,1))
        content.add_widget(Label(text='Editar producto', color=t))
        content.add_widget(in_n); content.add_widget(in_c); content.add_widget(in_p)
        btns = BoxLayout(size_hint_y=None, height=40)
        ok=Button(text='Guardar'); no=Button(text='Cancelar')
        btns.add_widget(ok); btns.add_widget(no)
        content.add_widget(btns)
        pop=Popup(title='Editar', content=content, size_hint=(0.8,0.6))
        ok.bind(on_release=lambda x: self._save_edit(prod[0], in_n, in_c, in_p, pop))
        no.bind(on_release=pop.dismiss)
        pop.open()

    def _save_edit(self, id, in_n, in_c, in_p, pop):
        try:
            nm=in_n.text.strip(); ct=int(in_c.text); pr=float(in_p.text)
            if not nm: raise ValueError('Nombre vacío')
            self.db.editar_producto(id, nm, ct, pr)
            self.load_productos(); pop.dismiss()
        except Exception as e:
            self.show_popup('Error', str(e))

    def show_popup(self, t, m):
        Popup(title=t, content=Label(text=m, color=t), size_hint=(0.6,0.4)).open()

class InventarioApp(App):
    def build(self):
        return ProductoForm()

if __name__=='__main__':
    InventarioApp().run()
