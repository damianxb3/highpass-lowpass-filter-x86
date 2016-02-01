#include <stdio.h>
#include <stdlib.h>
#include <gtk/gtk.h>

#ifdef __cplusplus
extern "C" {
#endif
void * func(unsigned char*, int[3][3], unsigned char*);
#ifdef __cplusplus
}
#endif

unsigned char * data;
GtkWidget *image_window;
GtkWidget *shown_image;
char file_chosen = 0;

void run_file_selector(GtkWidget*, GtkWidget*);
void load_file(GtkWidget*, GtkWidget*);
void process_file(GtkWidget*, GtkWidget*[3][3]);

int main(int argc, char *argv[]) {

	int i = 0, j = 0;	// iterators

	GtkWidget *tools_window;
	GtkWidget *choose_file_button;
	GtkWidget *filter_button;
	GtkWidget *tools_table;
	GtkWidget *kernel_ids[3][3];
	GtkWidget *file_selection;

	gtk_init(&argc, &argv);

	/// Image window:
	image_window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
	gtk_window_set_title(GTK_WINDOW(image_window), "Okno obrazu");
	gtk_widget_set_size_request(image_window, 800, 600);
	g_signal_connect(image_window, "delete-event", G_CALLBACK(gtk_widget_destroy), image_window);
	g_signal_connect_swapped(image_window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
	
	/// Tools window:
	tools_window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
	gtk_window_set_title(GTK_WINDOW(tools_window), "Narzędzia");
	gtk_widget_set_size_request(tools_window, 500, 150);
	g_signal_connect(tools_window, "delete-event", G_CALLBACK(gtk_widget_destroy), tools_window);
	g_signal_connect_swapped(tools_window, "destroy", G_CALLBACK(gtk_main_quit), NULL);

	/// Tools table:
	tools_table = gtk_table_new(6, 10, TRUE);
	gtk_container_add(GTK_CONTAINER(tools_window), tools_table);

	/// Kernel:
	for(i = 0; i < 3; ++i) {
		for(j = 0; j < 3; ++j) {
			kernel_ids[i][j] = gtk_spin_button_new_with_range(-10.0, 10.0, 1.0);
			gtk_table_attach_defaults(GTK_TABLE(tools_table), kernel_ids[i][j], 1+i, 2+i, 1+j, 2+j);
			gtk_spin_button_set_value(GTK_SPIN_BUTTON(kernel_ids[i][j]), 0.0);
			if(i == 1 && j == 1)
				gtk_spin_button_set_value(GTK_SPIN_BUTTON(kernel_ids[i][j]), 1.0);
			gtk_widget_show(kernel_ids[i][j]);
		}
	}

	///	File selection:
	file_selection = gtk_file_selection_new("Choose a *.bmp file");
	/// Choose file button:
	choose_file_button = gtk_button_new_with_label("Wybierz plik");
	gtk_table_attach_defaults(GTK_TABLE(tools_table), choose_file_button, 5, 9, 1, 3);
	g_signal_connect(choose_file_button, "clicked", G_CALLBACK(run_file_selector), file_selection);

	/// Filter button:
	filter_button = gtk_button_new_with_label("Przetwarzaj");
	gtk_table_attach_defaults(GTK_TABLE(tools_table), filter_button, 5, 9, 3, 5);
	g_signal_connect(filter_button, "clicked", G_CALLBACK(process_file), kernel_ids);

	gtk_widget_show(image_window);
	gtk_widget_show(choose_file_button);
	gtk_widget_show(filter_button);
	gtk_widget_show(tools_table);
	gtk_widget_show(tools_window);
	gtk_main();
	free(data);
	return 0;
}

void run_file_selector(GtkWidget *src, GtkWidget *file_selection) {
	g_signal_connect(GTK_FILE_SELECTION(file_selection)->ok_button, "clicked", G_CALLBACK(load_file), file_selection);
	g_signal_connect_swapped(GTK_FILE_SELECTION(file_selection)->cancel_button, "clicked", G_CALLBACK(gtk_widget_hide), file_selection);
	gtk_widget_show(file_selection);
}

void load_file(GtkWidget *src, GtkWidget *file_selection) {
	FILE *f;
	unsigned char BM[2];
	unsigned int size;

	file_chosen = 0;

	f = fopen(gtk_file_selection_get_filename(GTK_FILE_SELECTION(file_selection)), "rb");
	if(!f)
		return;
	fread(&BM, 2, 1, f);
	if(BM[0] != 'B' || BM[1] != 'M')
		return;
	
	fseek(f, 2, SEEK_SET); // [FILE+2] -- size
	fread(&size, 4, 1, f);

	data = (unsigned char*)malloc(size);
	fseek(f, 0, SEEK_SET);
	fread(data, size, 1, f);

	if(GTK_IS_WIDGET(shown_image))
		gtk_widget_destroy(shown_image);
	shown_image = gtk_image_new_from_file(gtk_file_selection_get_filename(GTK_FILE_SELECTION(file_selection)));
	gtk_container_add(GTK_CONTAINER(image_window), shown_image);
	gtk_widget_show(shown_image);

	fclose(f);
	file_chosen = 1;
	gtk_widget_hide(file_selection);
}

void process_file(GtkWidget *src, GtkWidget *kernel_ids[3][3]) {
	unsigned char * data_modified;
	unsigned int size;
	unsigned int offset;
	//unsigned int width;
	//unsigned int height;
	int filter[3][3];
	int i = 0;
	int j = 0;

	/// If no file is chosen:
	if(file_chosen == 0)
		return;

	/// Fill `filter` table and set the factor:
	for(i = 0; i != 3; ++i) {
		for(j = 0; j != 3; ++j) {
			filter[i][j] = (int)gtk_spin_button_get_value(GTK_SPIN_BUTTON(kernel_ids[i][j]));
		}
	}

	/// Getting information of the BMP image:
	size = *((int*)(data+2));
	offset = *((int*)(data+10));
	//width = *((int*)(data+18));
	//height = *((int*)(data+22));

	data_modified = (unsigned char*)malloc(size);

	/// Copy unprocessed data:
	for(i = 0; i < offset; ++i)
		data_modified[i] = data[i];

	// Filtering:
	func(data, filter, data_modified);

/// @todo : change to read from pixbuf
	FILE *f;
	f = fopen("tmp.bmp", "wb");
	fwrite(data_modified, 1, size, f);
	fclose(f);

	if(GTK_IS_WIDGET(shown_image))
		gtk_widget_destroy(shown_image);
	shown_image = gtk_image_new_from_file("tmp.bmp");
	gtk_container_add(GTK_CONTAINER(image_window), shown_image);
	gtk_widget_show(shown_image);

	remove("tmp.bmp");

	/*GdkPixbuf *pixbuf;
	pixbuf = gdk_pixbuf_new_from_data(data+offset, GDK_COLORSPACE_RGB, FALSE, 8, width, height, 3*width, NULL, NULL);


	if(GTK_IS_WIDGET(shown_image))
		gtk_widget_destroy(shown_image);
	shown_image = gtk_image_new_from_pixbuf(pixbuf);
	gtk_container_add(GTK_CONTAINER(image_window), shown_image);
	gtk_widget_show(shown_image);
	*/

	free(data_modified);
}
